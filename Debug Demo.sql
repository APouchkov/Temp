GO
/****** Object:  StoredProcedure [FrontOffice].[Query=Account:Compare@Execute(Internal)]    Script Date: 11.04.2018 17:22:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--===============================================================================================================
-- <Назначение>:        Обработка запроса на сравнение счета с внешними данными на дату;
-- <Дата создания>:     14.08.2017;
-----------------------------------------------------------------------------------------------------------------
-- <Пример>:
/*
DECLARE
    @InData     Xml,
    @OutData    Xml
;
-- SELECT * FROM [CIS.Data].[FrontOffice].[Accounts]
EXEC [FrontOffice].[Query=Account:Compare@Execute(Internal)]
    @Account_GUId           = '6D953E9F-9316-46F4-A00F-51428FD08F98',
    @Date                   = NULL,
    @Fields                 = '*',
    @InData                 = @InData,
    @OutData                = @OutData OUT;

SELECT
    [@OutData] = @OutData;
-- ROLLBACK TRAN

--*/
--===============================================================================================================
ALTER PROCEDURE [FrontOffice].[Query=Account:Compare@Execute(Internal)]
    @Account_GUId           UniqueIdentifier    = NULL,
    @Date                   Date                = NULL, -- NULL = Today
    @Fields                 VarChar(Max),
    @InData                 Xml,
    @OutData                Xml                 = NULL    OUT
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    --/*--<Debug>
    DECLARE
        @Debug                              TinyInt,
        @DebugParams                        [Debug].[Params],
        @DebugError                         NVarChar(1024),
        @DebugComment                       NVarChar(1024),
        @DebugRowCount                      Int,
        @DebugContext                       TParams;
    --*/--</Debug>

    DECLARE
        @DeadLockRetries                    TinyInt         = 5,
        @DeadLockDelay                      DateTime        = '00:00:00.500',
        @SavePoint                          SysName         = 'TRAN_FQACEI',
        @TranCount                          Int,
        @Retry                              TinyInt,
        @ErrorNumber                        Int,

        @RowCount                           Int,
        @Now                                DateTime        = GetDate(),
        @Today                              Date            = GetDate(),

        @SAccount_GUId                      VarChar(50),
        @Account_Id                         Int,
        @LData                              Xml,

        @Table_Id_Accounts                  SmallInt,
        @LFIELDS                            VarChar(Max);

     DECLARE @Results Table (
       [FieldName] VarChar(120),
       [IsEqual]   Bit
     );

     BEGIN TRY
        ------------------------------------------------------------------------
        --/*--<Debug>
        SET @Debug = Cast([System].[Session Variable]('DEBUG') AS TinyInt);
        INSERT INTO @DebugParams
        VALUES
            (1,     '@Account_GUId',        Cast(@Account_GUId AS NVarChar(50))),
            (2,     '@Date',                [Debug].[Date@ToString](@Date))
        EXEC [Debug].[Execution@Start] @Proc_Id = @@ProcId, @DebugContext = @DebugContext OUT, @Params = @DebugParams;
        --*/--</Debug>
        ------------------------------------------------------------------------
        -- Проверка параметров
        ------------------------------------------------------------------------
        IF @Date IS NULL
            SET @Date = GetDate();

        IF @Account_GUId IS NULL
            RaisError ('Abstract error: @Account_GUId IS NULL', 16, 2);

        SELECT TOP (1)
             @Account_Id = G.[Id]
        FROM [Base].[Objects:GUIds]  G
        WHERE G.[GUId]    = @Account_GUId;

        IF @Account_Id IS NULL BEGIN
            SET @SAccount_GUId = Cast(@Account_GUId AS NVarChar(50));
            RaisError ('Abstract error: Не найден счет по @Account_GUId = %s', 16, 2, @SAccount_GUId);
        END;

            ------------------------------------------------------------------------
        SET @TranCount = @@TranCount;
        SET @Retry = CASE WHEN @TranCount = 0 THEN @DeadLockRetries ELSE 1 END;
        WHILE (@Retry > 0)
        BEGIN TRY
            IF @TranCount > 0
                SAVE TRAN @SavePoint;
            ELSE
                BEGIN TRAN;

            --------------------------------------------------------------------
            -- Работа внутри транзакции
            --------------------------------------------------------------------
            SET @LData = NULL;

            -- Вешаем блокировку, чтобы счет не изменялся, пока формируем выгрузку по нему
            SELECT TOP (1)
                @Account_Id  = P.[Id]
            FROM [FrontOffice].[Accounts] P WITH (UPDLOCK, ROWLOCK)
            WHERE   P.[Id] = @Account_Id;

            SET @RowCount = @@RowCount;
            --------------------------------------------------------------------
            --/*--<Debug>
            SET @DebugRowCount  = @RowCount;
            SET @DebugComment   = N'(UPDLOCK, ROWLOCK) на [FrontOffice].[Accounts]';
            DELETE FROM @DebugParams;
            EXEC [Debug].[Execution@Point] @Proc_Id = @@ProcId, @DebugContext = @DebugContext OUT, @Comment = @DebugComment, @RowCount = @DebugRowCount, @Values = @DebugParams;
            --*/--</Debug>
            --------------------------------------------------------------------

            --------------------------------------------------------------------
            -- Формируем XML

            SET @LFIELDS    = 'Person_GUId,Contract_GUId,Type_Code,FirmType_Code,Number,OpenDate,CloseDate,ExpireDate,TerminationStartDate,TerminationReason_Code,TerminationInitiator_Code,Comments,ThirdParty_GUId';
            SET @LFIELDS    = [Pub].[Arrays Join](@LFIELDS, @FIELDS, ',');

            INSERT INTO @Results
                 ([FieldName], [IsEqual])
            SELECT DISTINCT
               CMP.[FieldName],
               CMP.[IsEqual]
            FROM [FrontOffice].[Message=Account@Parse](@InData) AS R
            CROSS APPLY
            (
                SELECT * FROM [FrontOffice].[Accounts]    C  WHERE C.[Id] = @Account_Id
            ) C
            OUTER APPLY
            (

                SELECT
                    [FieldName]     = 'Person_GUId',
                    [IsEqual]       = CASE WHEN
                                         (
                                           SELECT TOP 1 1
                                           FROM  [Base].[Objects:GUIds] PG
                                           WHERE PG.[Id] = C.[Person_Id]  AND
                                                 PG.[GUId] = R.[Person_GUId]
                                          ) IS NULL
                                          THEN 0 ELSE 1
                                      END
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'Contract_GUId',
                    [IsEqual]       = CASE WHEN
                                         (
                                           SELECT TOP 1 1
                                           FROM  [Base].[Objects:GUIds] PG
                                           WHERE PG.[Id] = C.[Contract_Id]  AND
                                                 PG.[GUId] = R.[Contract_GUId]
                                          ) IS NULL
                                          THEN 0 ELSE 1
                                      END
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'Type_Code',
                    [IsEqual]       = [Pub].[Is Equal Strings](R.[Type_Code], T.[Code], 0)
                FROM [FrontOffice].[Contracts->Types] T WHERE C.[Type_Id] = T.[Id]
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'FirmType_Code',
                    [IsEqual]       = [Pub].[Is Equal Strings](R.[FirmType_Code], F.[Code], 0)
                FROM [Firms].[Firms->Types] F WHERE C.[FirmType_Id] = F.[Id]
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'Number',
                    [IsEqual]       = [Pub].[Is Equal Strings](R.[Number], C.[Number], 0)
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'OpenDate',
                    [IsEqual]       = [Pub].[Is Equal Dates](R.[OpenDate], C.[OpenDate])
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'CloseDate',
                    [IsEqual]       = [Pub].[Is Equal Dates](R.[CloseDate], C.[CloseDate])
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'ExpireDate',
                    [IsEqual]       = [Pub].[Is Equal Dates](R.[ExpireDate], C.[ExpireDate])
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'TerminationInitiator_Code',
                    [IsEqual]       = [Pub].[Is Equal Strings](R.[TerminationInitiator_Code], S.[Code], 0)
                FROM [FrontOffice].[Terminations Initiators] S WHERE C.[TerminationInitiator_Id] = S.[Id]
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'TerminationReason_Code',
                    [IsEqual]       = [Pub].[Is Equal Strings](R.[TerminationReason_Code], TR.[Code], 0)
                FROM [FrontOffice].[Accounts->Terminations Reasons] TR WHERE C.[TerminationReason_Id] = TR.[Id]
                --
                UNION ALL
                --
                SELECT
                    [FieldName]     = 'TerminationStartDate',
                    [IsEqual]       = [Pub].[Is Equal Dates](R.[TerminationStartDate], C.[TerminationStartDate])
         ) CMP
         CROSS APPLY
         (
            SELECT [Value] from [Pub].[Array To RowSet Of Values](@LFIELDS,',') V WHERE V.[Value] = CMP.[FieldName]
         ) V
         WHERE CMP.[IsEqual] = 0;

         /*SET @LFIELDS    =
                         (
                            SELECT
                                [Pub].[Concat](PT.[FieldName], ',')
                            FROM [FrontOffice].[Objects:Options->Types] PT
                         );
         SET @LFIELDS    = [Pub].[Arrays Join](@LFIELDS, @FIELDS, ',');


         INSERT @Results ([FieldName], [IsEqual])
         SELECT
             [FieldName]     = T.[FieldName],
             [IsEqual]       = 0
         FROM [FrontOffice].[Objects:Options->Types] T
         INNER JOIN [Pub].[Split](@LFIELDS, ',')     TF  ON  TF.[Value] = T.[Code]
         LEFT JOIN
         (
             SELECT
                 [Type_Id]             = XO.[Type_Id],
                 [Value]               = XO.[Value],
                 [Base_GUId]           = XO.[Base_GUId],
                 [Base_Kind]           = XO.[BaseKind_Id]
             FROM [FrontOffice].[Message=Objects:Options@Parse]('/FRONTOFFICE-ACCOUNT-POV[1]/OPTIONS[1]') AS XO
         )      X   ON  X.[Type_Id] = T.[Id]
         OUTER APPLY
         (
             SELECT TOP (1)
                 [Value]     = PP.[Value],
                 [Base_GUId] = PB.[GUId],
                 [Base_Kind] = PB.[Kind_Id]
             FROM      [FrontOffice].[Objects:Options]      PP
             LEFT JOIN [FrontOffice].[Objects:Bases]        PB ON PP.[Base_Id] = PB.[Id]
             WHERE PP.[Object_Id] = @Account_Id
               AND T.[Id] = PP.[Type_Id]
               AND PP.[Date] <= @Date
             ORDER BY
                 PP.[Date] DESC
         ) PP
         WHERE [Pub].[Is Equal Strings](Cast(PP.[Value] AS NVarChar(Max)), X.[Value], 0) = 0
            OR [Pub].[Is Equal UniqueIdentifiers](X.[Base_GUId], PP.[Base_GUId]) = 0
            OR [Pub].[Is Equal Integers](X.[Base_Kind], PP.[Base_Kind]) = 0;*/

         SET @LData =
         (
             SELECT
                 [DIFFERENT_FIELDS] = [Pub].[Concat] (R.[FieldName], ',')
             FROM @Results R
             FOR XML RAW ('COMPARE-INFO'), TYPE
        );

        --------------------------------------------------------------------
        --/*--<Debug>
        SET @DebugComment   = N'Собираем @OutData';
        DELETE FROM @DebugParams;
        INSERT INTO @DebugParams
        VALUES
            (1, '@OutData',      Cast(@LData AS NVarChar(Max)));
        EXEC [Debug].[Execution@Point] @Proc_Id = @@ProcId, @DebugContext = @DebugContext OUT, @Comment = @DebugComment, @RowCount = NULL, @Values = @DebugParams;
        --*/--</Debug>
        --------------------------------------------------------------------

        FINALLY:
            WHILE @@TranCount > @TranCount COMMIT TRAN;
            SET @Retry = 0;
        END TRY
        ------------------------------------------------------------------------
        BEGIN CATCH
            SET @ErrorNumber = ERROR_NUMBER()
            IF @ErrorNumber IN (1205, 51205) BEGIN -- DEAD LOCK OR USER DEAD LOCK
                SET @ErrorNumber = 51205;
                SET @Retry = @Retry - 1;
            END ELSE
                SET @Retry = 0;

            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TranCount
                ROLLBACK TRAN;
            ELSE IF XACT_STATE() = 1 AND @@TRANCOUNT = @TranCount
                ROLLBACK TRAN @SavePoint;

            IF @@TRANCOUNT > 0 OR @Retry = 0
                EXEC [System].[ReRaise Error] @ErrorNumber = @ErrorNumber, @ProcedureId = @@ProcId;
            ELSE
                WAITFOR DELAY @DeadLockDelay;
        END CATCH;
        ------------------------------------------------------------------------
        --/*--<Debug>
          EXEC [Debug].[Execution@Finish] @Proc_Id = @@ProcId, @DebugContext = @DebugContext, @Return = 0, @Error = NULL;
        --*/--</Debug>

        SET @OutData   = @LData;

        RETURN (0);
        ------------------------------------------------------------------------
    END TRY
    BEGIN CATCH
        --/*--<Debug>
        SET @DebugError = Error_Message();
        EXEC [Debug].[Execution@Finish] @Proc_Id = @@ProcId, @DebugContext = @DebugContext, @Return = NULL, @Error = @DebugError;
        --*/--</Debug>

        EXEC [System].[ReRaise Error] @ProcedureId = @@ProcId;

        RETURN (-1);
    END CATCH;
