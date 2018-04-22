using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using System.IO;
using System.Text;
using LumenWorks.Framework.IO.Csv;
using MatriX.SQL.Files;
using Microsoft.SqlServer.Server;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void FilesCSVRead(SqlString filename, SqlString encoding, SqlBoolean useHeaders, char delimiter, char quote,
        SqlString tableName, SqlString databaseName, SqlString serverName, SqlBoolean doCreateTable, SqlBoolean doImpersonate)
    {
        if (filename == null || filename.IsNull)
            throw new NullReferenceException("File_Name should not be null");

        Utilities.Impersonate(doImpersonate, () =>
        {
            Encoding enc = encoding.IsNull ? Encoding.UTF8 : Encoding.GetEncoding(encoding.Value);
            using (var reader = new StreamReader(filename.Value, enc))
            {
                if (tableName == null || tableName.IsNull)
                    FilesCSVReadOutput(reader, useHeaders, delimiter, quote);
                else
                    FilesCSVReadBulk(reader, useHeaders, delimiter, quote, tableName, databaseName, serverName, doCreateTable);
            }
        });
    }

    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void FilesCSVReadText(SqlString csv, SqlBoolean useHeaders, char delimiter, char quote,
        SqlString tableName, SqlString databaseName, SqlString serverName, SqlBoolean doCreateTable, SqlBoolean doImpersonate)
    {
        if (csv == null || csv.IsNull)
            throw new NullReferenceException("CSV should not be null");

        Utilities.Impersonate(doImpersonate, () =>
        {
            using (var reader = new StringReader(csv.Value))
            {
                if (tableName == null || tableName.IsNull)
                    FilesCSVReadOutput(reader, useHeaders, delimiter, quote);
                else
                    FilesCSVReadBulk(reader, useHeaders, delimiter, quote, tableName, databaseName, serverName, doCreateTable);
            }
        });
    }

    private static void FilesCSVReadOutput(TextReader reader, SqlBoolean useHeaders, char delimiter, char quote)
    {
        using (var csv = new CsvReader(reader, useHeaders.IsTrue, delimiter, quote,
            CsvReader.DefaultEscape, CsvReader.DefaultComment, ValueTrimmingOptions.All))
        {
            //csv.SkipEmptyLines = true;
            //csv.SupportsMultiline = true;
            csv.DefaultHeaderName = "F";
            csv.MissingFieldAction = MissingFieldAction.ReplaceByNull;

            SqlDataRecord record = null;
            //long lineNo = useHeaders.IsTrue ? 1 : 0;
            long lineNo = 0;
            while (csv.ReadNextRecord())
            {
                if (record == null)
                {
                    int count = csv.FieldCount;
                    SqlMetaData[] columns = new SqlMetaData[count + 1];
                    columns[0] = new SqlMetaData("Line_No", SqlDbType.BigInt);
                    for (int i = 0; i < count; i++)
                    {
                        string field = GetFieldName(csv, useHeaders.IsTrue, i);
                        columns[i + 1] = new SqlMetaData(field, SqlDbType.NVarChar, 4000);
                    }
                    record = new SqlDataRecord(columns);
                    SqlContext.Pipe.SendResultsStart(record);
                }

                record.SetValue(0, lineNo);
                for (int i = 0; i < csv.FieldCount; i++)
                    record.SetValue(i + 1, csv[i]);
                for (int i = csv.FieldCount; i + 1 < record.FieldCount; i++)
                    record.SetValue(i + 1, null);

                SqlContext.Pipe.SendResultsRow(record);
                lineNo++;
            }
            if (record != null)
            {
                SqlContext.Pipe.SendResultsEnd();
            }
        }
    }

    private static void FilesCSVReadBulk(TextReader reader, SqlBoolean useHeaders, char delimiter, char quote,
        SqlString tableName, SqlString databaseName, SqlString serverName, SqlBoolean doCreateTable)
    {
        // http://stackoverflow.com/questions/10731179/bulk-insert-sql-server-millions-of-record
        // http://stackoverflow.com/questions/779478/sql-clr-sqlbulkcopy-from-datatable

        using (var csv = new CsvReader(reader, useHeaders.IsTrue, delimiter, quote,
            CsvReader.DefaultEscape, CsvReader.DefaultComment, ValueTrimmingOptions.All))
        {
            //csv.SkipEmptyLines = true;
            //csv.SupportsMultiline = true;
            csv.DefaultHeaderName = "F";
            csv.MissingFieldAction = MissingFieldAction.ReplaceByNull;

            SqlConnection cnnContext = null;
            try
            {
                SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder();
                csb.IntegratedSecurity = true;

                if (!serverName.IsNull)
                    csb.DataSource = serverName.Value;
                if (!databaseName.IsNull)
                    csb.InitialCatalog = databaseName.Value;

                bool isContextConnection = false;
                if (serverName.IsNull || databaseName.IsNull)
                {
                    isContextConnection = true;

                    cnnContext = new SqlConnection("context connection=true");
                    cnnContext.Open();
                    using (var cmd = cnnContext.CreateCommand())
                    {
                        if (serverName.IsNull)
                        {
                            cmd.CommandText = "select @@servername";
                            csb.DataSource = (string)cmd.ExecuteScalar();
                        }

                        if (databaseName.IsNull)
                        {
                            cmd.CommandText = "select db_name()";
                            csb.InitialCatalog = (string)cmd.ExecuteScalar();
                        }
                    }
                }

                using (SqlConnection cnnBulk = new SqlConnection(csb.ToString()))
                {
                    cnnBulk.Open();

                    string name = tableName.Value, name2 = null;
                    string sqlCopyData = null;
                    if (name.StartsWith("#") && !name.StartsWith("##"))
                    {
                        if (!isContextConnection)
                            throw new Exception("Cannot insert data into a temporary table via remote connection");

                        name2 = "##TEMP_Files_CSV_Read_" + Guid.NewGuid().ToString().Replace("-", "");
                        CreateTable(cnnBulk, name2, csv, useHeaders.IsTrue);
                        sqlCopyData = GetCopyDataSql(name, name2, csv, useHeaders.IsTrue);
                    }

                    if (doCreateTable.IsTrue && name2 == null)
                        CreateTable(isContextConnection ? cnnContext : cnnBulk, name, csv, useHeaders.IsTrue);

                    using (var bulk = new SqlBulkCopy(cnnBulk))
                    {
                        bulk.DestinationTableName = name2 ?? name;
                        bulk.WriteToServer(csv);
                    }

                    if (sqlCopyData != null)
                    {
                        // пока не закрыт bulk-connection - таблица ## существует. копируем данные из нее
                        using (var post = new SqlCommand(sqlCopyData, cnnContext))
                        {
                            post.CommandTimeout = 0;
                            post.ExecuteNonQuery();
                        }
                    }
                }
            }
            finally
            {
                if (cnnContext != null)
                    cnnContext.Dispose();
            }
        }
    }

    private static void CreateTable(SqlConnection cnn, string tablename, CsvReader csv, bool useHeaders)
    {
        StringBuilder sb = new StringBuilder();
        sb.Append("create table [").Append(tablename).Append("] (");
        for (int i = 0; i < csv.FieldCount; i++)
        {
            if (i > 0)
                sb.Append(", ");

            string field = GetFieldName(csv, useHeaders, i);
            sb.Append("[").Append(field).Append("] nvarchar(max)");
        }
        sb.Append(")");

        using (var cmd = new SqlCommand(sb.ToString(), cnn))
        {
            cmd.ExecuteNonQuery();
        }
    }

    private static string GetCopyDataSql(string tablenameTo, string tablenameFrom, CsvReader csv, bool useHeaders)
    {
        StringBuilder sb = new StringBuilder();
        sb.Append("insert into ").Append(tablenameTo); //.Append(" (");
        //for (int i = 0; i < csv.FieldCount; i++)
        //{
        //    if (i > 0)
        //        sb.Append(", ");

        //    string field = GetFieldName(csv, useHeaders, i);
        //    sb.Append("[").Append(field).Append("]");
        //}
        //sb.Append(") select ");
        sb.Append(" select ");
        for (int i = 0; i < csv.FieldCount; i++)
        {
            if (i > 0)
                sb.Append(", ");

            string field = GetFieldName(csv, useHeaders, i);
            sb.Append("[").Append(field).Append("]");
        }
        sb.Append(" from ").Append(tablenameFrom);
        return sb.ToString();
    }

    private static string GetFieldName(CsvReader csv, bool useHeaders, int i)
    {
        if (useHeaders)
        {
            var headers = csv.GetFieldHeaders();
            if (i < headers.Length)
                return headers[i];
        }
        return csv.DefaultHeaderName + (i + 1).ToString();
    }
};
