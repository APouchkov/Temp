// попытки вернуть xml из функции. SqlXml тормозит жутко при любых вариантах
//#define ReturnXml0

using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlTypes;
using System.IO;
using System.Text;
using System.Xml;
using LumenWorks.Framework.IO.Csv;
using Microsoft.SqlServer.Server;

public partial class UserDefinedFunctions
{
    class CsvFeed
    {
        public long lineNo { get; private set; }
        public CsvReader csv { get; private set; }

        private string[] _headers;
        public string[] headers
        {
            get
            {
                if (_headers == null)
                {
                    if (csv.HasHeaders)
                    {
                        _headers = csv.GetFieldHeaders();
                        for (int i = 0; i < _headers.Length; i++)
                            _headers[i] = XmlConvert.EncodeName(_headers[i].Replace(" ", "_"));
                    }
                    else
                    {
                        int count = csv.FieldCount;
                        _headers = new string[count];
                        for (int i = 0; i < count; i++)
                            _headers[i] = "F" + (i + 1).ToString();
                    }
                }
                return _headers;
            }
        }

        public CsvFeed(string filename, Encoding enc, bool useHeaders, char delimiter, char quote)
        {
            var sr = new StreamReader(filename, enc);
            csv = new CsvReader(sr, useHeaders, delimiter, quote,
                CsvReader.DefaultEscape, CsvReader.DefaultComment, ValueTrimmingOptions.All);
            csv.DefaultHeaderName = "F";
            csv.MissingFieldAction = MissingFieldAction.ReplaceByNull;

            lineNo = 0;
        }

        public IEnumerable<CsvFeed> Read()
        {
            try
            {
                while (csv.ReadNextRecord())
                {
                    lineNo++;
                    yield return this;
                }
            }
            finally
            {
                csv.Dispose();
            }
        }
    }

#if ReturnXml2
    class CsvXmlReader : XmlReader
    {
        private int _rowNo = -1, _attrNo = -1;
        private string[] _headers, _values;

        private string _value;
        private bool _valueRead;

        public CsvXmlReader(string[] headers, string[] values)
        {
            _headers = headers;
            _values = values;
        }

        public override int AttributeCount
        {
            get { return _values.Length; }
        }

        public override void Close()
        {
        }

        public override int Depth
        {
            get { return 0; }
        }

        public override string GetAttribute(int i)
        {
            return _values[i];
        }

        public override bool MoveToElement()
        {
            _attrNo = -1;
            _valueRead = false;;
            return true;
        }

        public override bool MoveToFirstAttribute()
        {
            _attrNo = 0;
            _valueRead = false;;
            return true;
        }

        public override bool MoveToNextAttribute()
        {
            _attrNo++;
            _valueRead = false;;
            return _attrNo < _values.Length;
        }

        public override bool Read()
        {
            _attrNo = -1;
            _rowNo++;
            _valueRead = false;;
            return _rowNo < 1;
        }

        public override bool HasValue
        {
            get { return _values[_attrNo] == null; }
        }

        public override bool ReadAttributeValue()
        {
            if (_valueRead)
                return false;

            _value = _values[_attrNo];
            _valueRead = true;
            return true;
        }

        public override string Name
        {
            get { return _attrNo < 0 ? "Row" : _headers[_attrNo]; }
        }

        public override string Value
        {
            get { return _value; }
        }

        public override string GetAttribute(string name)
        {
            throw new NotImplementedException();
        }

        public override bool MoveToAttribute(string name)
        {
            throw new NotImplementedException();
        }

        public override bool EOF
        {
            get { return _rowNo > 0; }
        }

        public override string BaseURI
        {
            get
            {
                throw new Exception("The method or operation is not implemented.");
            }
        }

        public override string GetAttribute(string name, string namespaceURI)
        {
            throw new Exception("The method or operation is not implemented.");
        }

        public override bool IsEmptyElement
        {
            get { return true; }
        }

        public override string LocalName
        {
            get { return _attrNo < 0 ? "Row" : _headers[_attrNo]; }
        }

        public override string LookupNamespace(string prefix)
        {
            throw new Exception("The method or operation is not implemented.");
        }

        public override bool MoveToAttribute(string name, string ns)
        {
            throw new Exception("The method or operation is not implemented.");
        }

        public override XmlNameTable NameTable
        {
            get { throw new Exception("The method or operation is not implemented."); }
        }

        public override string NamespaceURI
        {
            get { return string.Empty; }
        }

        public override XmlNodeType NodeType
        {
            get
            {
                if (_attrNo < 0)
                    return XmlNodeType.Element;
                else if (_attrNo < _values.Length)
                    return XmlNodeType.Attribute;
                else
                    return XmlNodeType.EndElement;
            }
        }

        public override string Prefix
        {
            get { return string.Empty; }
        }

        public override ReadState ReadState
        {
            get
            {
                if (_rowNo < 0)
                    return System.Xml.ReadState.Initial;
                else if (_rowNo == 0)
                    return System.Xml.ReadState.Interactive;
                else
                    return System.Xml.ReadState.EndOfFile;
            }
        }

        public override void ResolveEntity()
        {
            throw new Exception("The method or operation is not implemented.");
        }
    }
#endif

    //*****************************
    [SqlFunction(Name = "xdf_Files_CSV_Read", FillRowMethodName = "FilesCSVReadFunc_FillRow", TableDefinition = "Line_No bigint, Data nvarchar(max)", DataAccess = DataAccessKind.Read)]
    public static IEnumerable FilesCSVReadFunc(SqlString filename, SqlString encoding, SqlBoolean useHeaders, char delimiter, char quote, SqlBoolean doImpersonate)
    {
        if (filename == null || filename.IsNull)
            throw new NullReferenceException("File_Name cannot be null");

        // TODO: doImpersonate?
        Encoding enc = encoding.IsNull ? Encoding.UTF8 : Encoding.GetEncoding(encoding.Value);
        var feed = new CsvFeed(filename.Value, enc, useHeaders.IsTrue, delimiter, quote);
        return feed.Read();
    }

    public static void FilesCSVReadFunc_FillRow(Object obj, out long lineNo, out string data)
    {
        CsvFeed feed = obj as CsvFeed;

        StringWriter sw = new StringWriter();
        XmlTextWriter xml = new XmlTextWriter(sw);
        xml.WriteStartElement("Row");
        var headers = feed.headers;
        for (int i = 0; i < feed.csv.FieldCount; i++)
        {
            string value = feed.csv[i];
            if (value != null)
                xml.WriteAttributeString(headers[i], value);
        }
        xml.WriteEndElement();
        xml.Close();

        lineNo = feed.lineNo;
        data = sw.ToString();

#if ReturnXml0
        StringWriter sw = new StringWriter();
        XmlTextWriter xml = new XmlTextWriter(sw);
        xml.WriteStartElement("Row");
        var headers = feed.headers;
        for (int i = 0; i < feed.csv.FieldCount; i++)
        {
            string value = feed.csv[i];
            if (value != null)
                xml.WriteAttributeString(headers[i], value);
        }
        xml.WriteEndElement();
        xml.Flush();
        xml.Close();
        
        lineNo = feed.lineNo;
        MemoryStream ms = new MemoryStream(Encoding.UTF8.GetBytes(sw.ToString()));
        data = new SqlXml(ms);
#endif

#if ReturnXml1
        MemoryStream ms = new MemoryStream();
        XmlTextWriter xml = new XmlTextWriter(ms, Encoding.UTF8);
        xml.WriteStartElement("Row");
        var headers = feed.headers;
        for (int i = 0; i < feed.csv.FieldCount; i++)
        {
            string value = feed.csv[i];
            if (value != null)
                xml.WriteAttributeString(headers[i], value);
        }
        xml.WriteEndElement();
        xml.Flush();
        ms.Position = 0;
        //xml.Close();

        lineNo = feed.lineNo;
        data = new SqlXml(ms);
#endif

#if ReturnXml2
        lineNo = feed.lineNo;
        int count = feed.csv.FieldCount;
        string[] values = new string[count];
        for (int i = 0; i < count; i++)
            values[i] = feed.csv[i];
        data = new SqlXml(new CsvXmlReader(feed.headers, values));
#endif
    }

    //*****************************
    [SqlFunction(Name = "xdf_Files_CSV_Read_20", FillRowMethodName = "FilesCSVReadFunc_FillRow20", DataAccess = DataAccessKind.Read,
        TableDefinition = @"Line_No bigint, F1 nvarchar(max), F2 nvarchar(max), F3 nvarchar(max), F4 nvarchar(max), F5 nvarchar(max), F6 nvarchar(max), F7 nvarchar(max), F8 nvarchar(max), F9 nvarchar(max), F10 nvarchar(max), F11 nvarchar(max), F12 nvarchar(max), F13 nvarchar(max), F14 nvarchar(max), F15 nvarchar(max), F16 nvarchar(max), F17 nvarchar(max), F18 nvarchar(max), F19 nvarchar(max), F20 nvarchar(max)")]
    public static IEnumerable FilesCSVReadFunc20(SqlString filename, SqlString encoding, SqlBoolean useHeaders, char delimiter, char quote, SqlBoolean doImpersonate)
    {
        if (filename == null || filename.IsNull)
            throw new NullReferenceException("File_Name cannot be null");

        // TODO: doImpersonate? useHeader бессмысленный?
        Encoding enc = encoding.IsNull ? Encoding.UTF8 : Encoding.GetEncoding(encoding.Value);
        var feed = new CsvFeed(filename.Value, enc, useHeaders.IsTrue, delimiter, quote);
        return feed.Read();
    }

    public static void FilesCSVReadFunc_FillRow20(Object obj, out long lineNo,
        out string F1, out string F2, out string F3, out string F4,
        out string F5, out string F6, out string F7, out string F8,
        out string F9, out string F10, out string F11, out string F12,
        out string F13, out string F14, out string F15, out string F16,
        out string F17, out string F18, out string F19, out string F20)
    {
        CsvFeed feed = obj as CsvFeed;
        CsvReader csv = feed.csv;
        int count = csv.FieldCount;

        lineNo = feed.lineNo;
        F1 = (count > 0) ? csv[0] : null;
        F2 = (count > 1) ? csv[1] : null;
        F3 = (count > 2) ? csv[2] : null;
        F4 = (count > 3) ? csv[3] : null;
        F5 = (count > 4) ? csv[4] : null;
        F6 = (count > 5) ? csv[5] : null;
        F7 = (count > 6) ? csv[6] : null;
        F8 = (count > 7) ? csv[7] : null;
        F9 = (count > 8) ? csv[8] : null;
        F10 = (count > 9) ? csv[9] : null;
        F11 = (count > 10) ? csv[10] : null;
        F12 = (count > 11) ? csv[11] : null;
        F13 = (count > 12) ? csv[12] : null;
        F14 = (count > 13) ? csv[13] : null;
        F15 = (count > 14) ? csv[14] : null;
        F16 = (count > 15) ? csv[15] : null;
        F17 = (count > 16) ? csv[16] : null;
        F18 = (count > 17) ? csv[17] : null;
        F19 = (count > 18) ? csv[18] : null;
        F20 = (count > 19) ? csv[19] : null;
    }
}
