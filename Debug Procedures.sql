
GO

/****** Object:  StoredProcedure [Debug].[Exection@Finish]    Script Date: 04/11/2018 16:31:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--===============================================================================================================
-- <Назначение>:        Сохранение окончания логирования процедуры;
-- <Автор>:             Gagarkin;
-- <Дата создания>:     23.06.2016;
-- <Комментарий>:       ;
---===============================================================================================================
CREATE PROCEDURE [Debug].[Exection@Finish]
    @Proc_Id                Int,
    @DebugContext           TParams,
    @Return                 Int,
    @Error                  NVarChar(1024)
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    DECLARE
        @DEBUG              TinyInt,
        @DebugContextBin    VarBinary(8000),
        @PrintMessage       NVarChar(1024),
        @Execution_Id       BigInt,
        @AfterExec_Id       BigInt,
        @StartDateTime      DateTime2,
        @DateTime           DateTime2,
        @SubDateTime        DateTime2,
        @LastIndex          Int,
        @TranCount          Int,
        @Now                DateTime2;

    BEGIN TRY
        -- Проверка параметров
        IF @Proc_Id IS NULL
            RaisError('Abstract error: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Exection@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @TranCount      = @@TranCount;
        SET @Now            = GetDate();
        SET @DEBUG          = Cast([System].[Session Variable]('DEBUG') AS TinyInt);
        SET @Execution_Id   = @DebugContext.AsBigInt('Execution_Id');
        SET @StartDateTime  = @DebugContext.AsDateTime2('StartDateTime');

        IF @Execution_Id IS NULL BEGIN
            PRINT '[Debug].[Exection@Finish]: DEBUG ERROR!!!';
            RETURN (-1);
        END;

        INSERT INTO [Debug].[Execution:Finish]
        (
            [Id],
            [EndDateTime],
            [Duration],
            [Return],
            [Error],
            [TranCount]
        )
        VALUES
        (
            @Execution_Id,
            @Now,
            DateDiff(ms, @StartDateTime, @Now),
            @Return,
            @Error,
            @TranCount
        );

        IF @DEBUG <> 0 BEGIN
            IF @DEBUG & 0x01 <> 0 BEGIN
                -- SELECT [@Now] = @Now, [@StartDateTime] = @StartDateTime
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'')
                                    + QuoteName(Object_Schema_Name(@Proc_Id)) + N'.' + QuoteName(Object_Name(@Proc_Id))
                                    + N' End point <<' + Convert(NVarChar(20), DateAdd(ms, DateDiff(ms, @StartDateTime, @Now), Cast('00:00:00' AS Time(3))), 114) + '>> (Ret:' + IsNull(Cast(@Return AS NVarChar(20)), N'NULL') + N')' + IsNull(N' /' + @Error + N'/', N'') + N'.';
                PRINT (@PrintMessage);
            END;
        END;

        SET @AfterExec_Id = @Execution_Id;

        -- Восстанавливаем
        SELECT TOP (1)
            @Execution_Id   = P.[Id],
            @StartDateTime  = P.[StartDateTime],
            @DateTime       = CASE WHEN SA.[Kind] = 'a' THEN A.[DateTime] ELSE SA.[DateTime] END,
            @SubDateTime    = SA.[DateTime],
            @LastIndex      = SA.[Index]
        FROM [Debug].[Execution:Start]        S
        INNER JOIN [Debug].[Execution:Start]  P ON P.[Id] = S.[Parent_Id]
        OUTER APPLY
        (
            SELECT TOP (1)
            T.[Index],
            T.[DateTime],
            T.[Kind]
            FROM [Debug].[Execution:Stmt] T
            WHERE T.[Exec_Id] = P.[Id]
            ORDER BY T.[Index] DESC
        ) SA
        OUTER APPLY
        (
            SELECT TOP (1)
            T.[Index],
            T.[DateTime]
            FROM [Debug].[Execution:Stmt] T
            WHERE SA.[Kind] = 'a'
            AND T.[Exec_Id] = P.[Id]
            AND T.[Kind] = 'A'
            ORDER BY T.[Index] DESC
        ) A
        WHERE S.[Id] = @Execution_Id;

        IF @@RowCount = 0 BEGIN
            SET @DebugContextBin = NULL;
        END ELSE BEGIN
            SET @DebugContext     = TParams::New()
                                    .[Add]('Execution_Id',  @Execution_Id)
                                    .[Add]('StartDateTime', @StartDateTime)
                                    .[Add]('DateTime',      @DateTime)
                                    .[Add]('SubDateTime',   @SubDateTime)
                                    .[Add]('LastIndex',     0)
                                    .[Add]('AfterExec_Id',  @AfterExec_Id);
            SET @DebugContextBin  = Cast(@DebugContext AS VArBinary(8000));
        END;

        EXEC [System].[Session Variable@Set]
                @Name   = 'DEBUG.Context',
                @Value  = @DebugContextBin;

        RETURN (0);
    END TRY
    BEGIN CATCH
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID;
    END CATCH;

GO

/****** Object:  StoredProcedure [Debug].[Exection@Point]    Script Date: 04/11/2018 16:31:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--===============================================================================================================
-- <Назначение>:        Сохранение точки логирования процедуры;
-- <Автор>:             Gagarkin;
-- <Дата создания>:     23.06.2016;
-- <Комментарий>:       ;
---===============================================================================================================
CREATE PROCEDURE [Debug].[Exection@Point]
    @Proc_Id                Int,
    @DebugContext           TParams           OUT,
    @Comment                NVarChar(1024),
    @RowCount               Int               = NULL,
    @Values                 [Debug].[Params]  READONLY
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    DECLARE
        @DEBUG              TinyInt,
        @DebugContextBin    VarBinary(8000),
        @PrintMessage       NVarChar(1024),
        @Execution_Id       BigInt,
        @DateTime           DateTime2,
        @SubDateTime        DateTime2,
        @LastIndex          Int,
        @TranCount          Int,
        @AfterExec_Id       BigInt,
        @Now                DateTime2;

    BEGIN TRY
        -- Проверка параметров
        IF @Proc_Id IS NULL
            RaisError('Abstract error: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Exection@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @TranCount      = @@TranCount;
        SET @Now            = GetDate();
        SET @DEBUG          = Cast([System].[Session Variable]('DEBUG') AS TinyInt);
        SET @Execution_Id   = @DebugContext.AsBigInt('Execution_Id');
        SET @DateTime       = @DebugContext.AsDateTime2('DateTime');
        SET @SubDateTime    = @DebugContext.AsDateTime2('SubDateTime');
        SET @LastIndex      = @DebugContext.AsInt('LastIndex') + 1;
        SET @AfterExec_Id   = @DebugContext.AsBigInt('AfterExec_Id');

        -------------------------------------------------------------------------
        -- Сохраняем отладочную точку
        INSERT INTO [Debug].[Execution:Stmt]
        (
            [Exec_Id],
            [Index],
            [AfterExec_Id],
            [Kind],
            [DateTime],
            [Duration],
            [Comment],
            [Rows],
            [TranCount],
            ----
            [Value1.Name],
            [Value1.Value],
            [Value2.Name],
            [Value2.Value],
            [Value3.Name],
            [Value3.Value],
            [Value4.Name],
            [Value4.Value]
        )
        SELECT
            @Execution_Id,
            @LastIndex,
            @AfterExec_Id,
            'P',
            @Now,
            DateDiff(MilliSecond, @DateTime, @Now),
            @Comment,
            @RowCount,
            @TranCount,
            ----
            P1.[Name],
            P1.[Value],
            P2.[Name],
            P2.[Value],
            P3.[Name],
            P3.[Value],
            P4.[Name],
            P4.[Value]
        FROM (VALUES (NULL)) R([Null])
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 1) P1
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 2) P2
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 3) P3
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 4) P4;

        INSERT INTO [Debug].[Execution:OtherParams]
            ( [Id], [Index], [Name], [Value] )
        SELECT
            @Execution_Id, [Index], [Name], [Value]
        FROM @Values
        WHERE [Index] >= 7;

        SET @DebugContext.AddParam('DateTime', @Now);
        SET @DebugContext.AddParam('SubDateTime', @Now);
        SET @DebugContext.AddParam('LastIndex', @LastIndex);
        SET @DebugContext.AddParam('AfterExec_Id', NULL);
        SET @DebugContextBin = Cast(@DebugContext AS VarBinary(8000));

        EXEC [System].[Session Variable@Set]
            @Name     = 'DEBUG.Context',
            @Value    = @DebugContextBin;

        IF @DEBUG <> 0 BEGIN
            IF @DEBUG & 0x01 <> 0 BEGIN
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'')
                                    + N'..' + QuoteName(Object_Schema_Name(@Proc_Id)) + N'.' + QuoteName(Object_Name(@Proc_Id))
                                    + N' (' + Convert(NVarChar(20), DateAdd(ms, DateDiff(ms, @DateTime, @Now), Cast('00:00:00' AS Time(3))), 114) + ') [' + IsNull(Cast(@RowCount AS NVarChar(20)), N'NULL') + N']: ' + IsNull(@Comment, N'');
                PRINT (@PrintMessage);
            END;
            IF @DEBUG & 0x02 <> 0 BEGIN
                SELECT
                    [DebugInfo.Point]   = QuoteName(Object_Schema_Name(@Proc_Id)) + N'.' + QuoteName(Object_Name(@Proc_Id)),
                    [Comment]           = @Comment,
                    ----
                    [Values1.Name]      = V1.[Name],
                    [Values1.Value]     = V1.[Value],
                    [Values2.Name]      = V2.[Name],
                    [Values2.Value]     = V2.[Value],
                    [Values3.Name]      = V3.[Name],
                    [Values3.Value]     = V3.[Value],
                    [Values4.Name]      = V4.[Name],
                    [Values4.Value]     = V4.[Value]
                FROM (VALUES (NULL)) R([Null])
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 1) V1
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 2) V2
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 3) V3
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 4) V4;
            END;
        END;

        RETURN (0);
    END TRY
    BEGIN CATCH
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID;
    END CATCH;

GO

/****** Object:  StoredProcedure [Debug].[Exection@Start]    Script Date: 04/11/2018 16:31:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--===============================================================================================================
-- <Назначение>:        Процедура начала логирования процедуры;
-- <Автор>:             Gagarkin;
-- <Дата создания>:     22.06.2016;
-- <Комментарий>:       ;
---===============================================================================================================
CREATE PROCEDURE [Debug].[Exection@Start]
    @Proc_Id                    Int,
    @DebugContext               TParams             OUT,
    @Params                     [Debug].[Params]    READONLY
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON

    DECLARE
        @DEBUG                  TinyInt,
        @TranCount              Int,
        @PrintMessage           NVarChar(1024),
        @Execution_Id           BigInt,
        @DebugContextBin        VarBinary(8000),
        @ParentDebugContext     TParams,
        @ParentExecution_Id     BigInt,
        @StartDateTime          DateTime2;

    BEGIN TRY
        -- Проверка параметров
        IF @Proc_Id IS NULL
            RaisError('Abstract error: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Exection@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @TranCount          = @@TranCount;
        SET @StartDateTime      = GetDate();
        SET @DEBUG              = Cast([System].[Session Variable]('DEBUG') AS TinyInt);
        IF @@NestLevel - 1 > 1 BEGIN
            -- Parent может быть только, если логируемая процедура не верхнего уровня
            SET @DebugContextBin    = Cast([System].[Session Variable]('DEBUG.Context') AS VarBinary(8000));
            SET @ParentDebugContext = Cast(@DebugContextBin AS TParams);
        END;

        -------------------------------------------------------------------------
        -- Формируем факт запуска процедуры
        INSERT INTO [Debug].[Execution:Start]
        (
            [Parent_Id],
            [Database],
            [Schema],
            [Object],
            [Object_Id],
            ----
            [StartDateTime],
            ----
            [NestLevel],
            [HostName],
            [LoginName],
            [UserName],
            [SpId],
            [TranCount],
            ----
            [Param1.Name],
            [Param1.Value],
            [Param2.Name],
            [Param2.Value],
            [Param3.Name],
            [Param3.Value],
            [Param4.Name],
            [Param4.Value],
            [Param5.Name],
            [Param5.Value],
            [Param6.Name],
            [Param6.Value]
        )
        SELECT
            @ParentDebugContext.AsBigInt('Execution_Id'),
            Db_Name(),
            Object_Schema_Name(@Proc_Id),
            Object_Name(@Proc_Id),
            @Proc_Id,
            ----
            GetDate(),
            ----
            @@NestLevel - 1,
            Host_Name(),
            Original_Login(),
            User_Name(),
            @@SpId,
            @TranCount,
            ----
            P1.[Name],
            P1.[Value],
            P2.[Name],
            P2.[Value],
            P3.[Name],
            P3.[Value],
            P4.[Name],
            P4.[Value],
            P5.[Name],
            P5.[Value],
            P6.[Name],
            P6.[Value]
        FROM (VALUES (NULL)) R([Null])
        OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 1) P1
        OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 2) P2
        OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 3) P3
        OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 4) P4
        OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 5) P5
        OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 6) P6;

        SET @Execution_Id = Scope_Identity();

        INSERT INTO [Debug].[Execution:OtherParams]
            ( [Id], [Index], [Name], [Value] )
        SELECT
            @Execution_Id, [Index], [Name], [Value]
        FROM @Params
        WHERE [Index] >= 7;

        SET @DebugContext     = TParams::New()
                                .[Add]('Execution_Id',  @Execution_Id)
                                .[Add]('StartDateTime', @StartDateTime)
                                .[Add]('DateTime',      @StartDateTime)
                                .[Add]('SubDateTime',   @StartDateTime)
                                .[Add]('LastIndex',     0);
        SET @DebugContextBin  = Cast(@DebugContext AS VArBinary(8000));
        EXEC [System].[Session Variable@Set]
                @Name   = 'DEBUG.Context',
                @Value  = @DebugContextBin;

        IF @DEBUG <> 0 BEGIN
            IF @DEBUG & 0x01 <> 0 BEGIN
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'') + QuoteName(Object_Schema_Name(@Proc_Id)) + N'.' + QuoteName(Object_Name(@Proc_Id)) + N' Start point. ----------------------------------------';
                PRINT (@PrintMessage);
            END
            IF @DEBUG & 0x02 <> 0 BEGIN
                SELECT
                    [DebugInfo.Start]   = QuoteName(Object_Schema_Name(@Proc_Id)) + N'.' + QuoteName(Object_Name(@Proc_Id)),
                    ----
                    [Param1.Name]   = P1.[Name],
                    [Param1.Value]  = P1.[Value],
                    [Param2.Name]   = P2.[Name],
                    [Param2.Value]  = P2.[Value],
                    [Param3.Name]   = P3.[Name],
                    [Param3.Value]  = P3.[Value],
                    [Param4.Name]   = P4.[Name],
                    [Param4.Value]  = P4.[Value],
                    [Param5.Name]   = P5.[Name],
                    [Param5.Value]  = P5.[Value],
                    [Param6.Name]   = P6.[Name],
                    [Param6.Value]  = P6.[Value]
                FROM (VALUES (NULL)) R([Null])
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 1) P1
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 2) P2
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 3) P3
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 4) P4
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 5) P5
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 6) P6;
            END;
        END;

        RETURN (0);
    END TRY
    BEGIN CATCH
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID
    END CATCH;

GO

/****** Object:  StoredProcedure [Debug].[Exection@SubPoint]    Script Date: 04/11/2018 16:31:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--===============================================================================================================
-- <Назначение>:        Сохранение суб-точки логирования процедуры;
-- <Автор>:             Gagarkin;
-- <Дата создания>:     23.06.2016;
-- <Комментарий>:       ;
---===============================================================================================================
CREATE PROCEDURE [Debug].[Exection@SubPoint]
    @Proc_Id                Int,
    @DebugContext           TParams           OUT,
    @Comment                NVarChar(1024),
    @RowCount               Int               = NULL,
    @Values                 [Debug].[Params]  READONLY
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON

    DECLARE
        @DEBUG              TinyInt,
        @DebugContextBin    VarBinary(8000),
        @PrintMessage       NVarChar(1024),
        @Execution_Id       BigInt,
        @StartDateTime      DateTime2,
        @SubDateTime        DateTime2,
        @LastIndex          Int,
        @TranCount          Int,
        @AfterExec_Id       BigInt,
        @Now                DateTime2;

    BEGIN TRY
        -- Проверка параметров
        IF @Proc_Id IS NULL
            RaisError('Abstract error: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Exection@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @TranCount      = @@TranCount;
        SET @Now            = GetDate();
        SET @DEBUG          = Cast([System].[Session Variable]('DEBUG') AS TinyInt);
        SET @Execution_Id   = @DebugContext.AsBigInt('Execution_Id');
        SET @SubDateTime    = @DebugContext.AsDateTime2('SubDateTime');
        SET @LastIndex      = @DebugContext.AsInt('LastIndex') + 1;
        SET @AfterExec_Id   = @DebugContext.AsBigInt('AfterExec_Id');
        -------------------------------------------------------------------------

        -- Сохраняем отладочную Суб-точку
        INSERT INTO [Debug].[Execution:Stmt]
        (
            [Exec_Id],
            [Index],
            [AfterExec_Id],
            [Kind],
            [DateTime],
            [Duration],
            [Comment],
            [Rows],
            [TranCount],
            ----
            [Value1.Name],
            [Value1.Value],
            [Value2.Name],
            [Value2.Value],
            [Value3.Name],
            [Value3.Value],
            [Value4.Name],
            [Value4.Value]
        )
        SELECT
            @Execution_Id,
            @LastIndex,
            @AfterExec_Id,
            'p',
            @Now,
            DateDiff(MilliSecond, @SubDateTime, @Now),
            @Comment,
            @RowCount,
            @TranCount,
            ----
            P1.[Name],
            P1.[Value],
            P2.[Name],
            P2.[Value],
            P3.[Name],
            P3.[Value],
            P4.[Name],
            P4.[Value]
        FROM (VALUES (NULL)) R([Null])
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 1) P1
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 2) P2
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 3) P3
        OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 4) P4;

        SET @DebugContext.AddParam('SubDateTime', @Now);
        SET @DebugContext.AddParam('LastIndex', @LastIndex);
        SET @DebugContext.AddParam('AfterExec_Id', NULL);
        SET @DebugContextBin = Cast(@DebugContext AS VarBinary(8000));

        EXEC [System].[Session Variable@Set]
            @Name     = 'DEBUG.Context',
            @Value    = @DebugContextBin;

        IF @DEBUG <> 0 BEGIN
            IF @DEBUG & 0x01 <> 0 BEGIN
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'')
                                    + '..--' + QuoteName(Object_Schema_Name(@Proc_Id)) + N'.' + QuoteName(Object_Name(@Proc_Id))
                                    + N' /' + Convert(NVarChar(20), DateAdd(ms, DateDiff(ms, @SubDateTime, @Now), Cast('00:00:00' AS Time(3))), 114) + '/ [' + IsNull(Cast(@RowCount AS NVarChar(20)), N'NULL') + N']: ' + IsNull(@Comment, N'');
                PRINT (@PrintMessage);
            END
            IF @DEBUG & 0x04 <> 0 BEGIN
                SELECT
                    [DebugInfo.SubPoint]  = QuoteName(Object_Schema_Name(@Proc_Id)) + N'.' + QuoteName(Object_Name(@Proc_Id)),
                    [Comment]             = @Comment,
                    ----
                    [Values1.Name]      = V1.[Name],
                    [Values1.Value]     = V1.[Value],
                    [Values2.Name]      = V2.[Name],
                    [Values2.Value]     = V2.[Value],
                    [Values3.Name]      = V3.[Name],
                    [Values3.Value]     = V3.[Value],
                    [Values4.Name]      = V4.[Name],
                    [Values4.Value]     = V4.[Value]
                FROM (VALUES (NULL)) R([Null])
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 1) V1
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 2) V2
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 3) V3
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 4) V4;
            END;
        END;

        RETURN (0);
    END TRY
    BEGIN CATCH
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID;
    END CATCH;

GO

/****** Object:  StoredProcedure [Debug].[Execution@Finish]    Script Date: 04/11/2018 16:31:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--==================================================================================================
-- <Назначение>:        Сохранение окончания логирования процедуры;
-- <Версия>:            v3.0;
-- <Дата создания>:     23.06.2016;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       ;
----------------------------------------------------------------------------------------------------
-- <Версия>:            v4.0;
-- <Дата>:              07.01.2018;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       С использованием Extended Events;
---=================================================================================================
CREATE PROCEDURE [Debug].[Execution@Finish]
    @Proc_Id                    Int,
    @DebugContext               TParams,
    @Return                     Int,
    @Error                      NVarChar(1024)
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    DECLARE
        @Event_Id                   Int                 = 82,   -- Пока зашиваем жестко!

        @DEBUG                      TinyInt,                    -- Bit-маска режима отладки
                                                                -- 0x01 -- вывод таймингов
                                                                -- 0x02 -- вывод значений переменных
                                                                -- 0x04 -- вывод табличных данных

        @DbName                     SysName             = Db_Name(),
        @ObjectSchema               SysName,
        @ObjectName                 SysName,

        @PrintMessage               NVarChar(1024),
        @Execution_Id               BigInt,
        @StartDateTime              DateTime2(3),
        @Now                        DateTime2(3),

        @EventInfo                  NVarChar(128),

        @EventJData                 NVarChar(4000),
        @EventData                  VarBinary(8000);

    ----------------------------------------------------------------------------
    BEGIN TRY
    ----------------------------------------------------------------------------
        -- Проверка параметров
        ------------------------------------------------------------------------
        IF @Proc_Id IS NULL
            RaisError('DEBUG ERROR: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Execution@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @ObjectSchema   = Object_Schema_Name(@Proc_Id);
        SET @ObjectName     = Object_Name(@Proc_Id);

        IF @ObjectSchema IS NULL OR @ObjectName IS NULL
            RaisError('DEBUG ERROR: Invalid @Proc_Id = %i', 16, 2, @Proc_Id);

        IF @DebugContext IS NULL
            RaisError('DEBUG ERROR: @DebugContext IS NULL', 16, 2);

        SET @Now                = GetDate();
        SET @DEBUG              = Cast([System].[Session Variable]('DEBUG') AS TinyInt);

        SET @Execution_Id       = @DebugContext.AsBigInt('Execution_Id');
        SET @StartDateTime      = @DebugContext.AsDateTime2('StartDateTime');

        IF @Execution_Id IS NULL
            RaisError('DEBUG ERROR: @Execution_Id IS NULL', 16, 2);

        ------------------------------------------------------------------------
        -- Формируем событие (Extended Event) для факта вызова
        ------------------------------------------------------------------------
        SET @EventInfo  =
            (
                SELECT
                    [Kind]      = 'Finish',
                    [Id]        = @Execution_Id,
                    [EType]     = 'Info'
                FOR JSON PATH
            );

        SET @EventJData =   (
                                SELECT
                                    [SpId]              = @@SpId,
                                    [Object_Id]         = @Proc_Id,
                                    [DateTime]          = @Now,
                                    [Duration]          = DateDiff(MilliSecond, @StartDateTime, @Now),
                                    [Return]            = @Return,
                                    [TranCount]         = @@TranCount,
                                    [Error]             = @Error
                                FOR JSON PATH
                            );
        SET @EventData  =   Cast(@EventJData AS VarBinary(8000));

        ------------------------------------------------------------------------
        EXEC [sys].[sp_trace_generateevent]
            @eventid    = @Event_Id,
            @userinfo   = @EventInfo,
            @userdata   = @EventData;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        IF @DEBUG <> 0 BEGIN
        ------------------------------------------------------------------------
            -- Вывод таймингов + параметров
            --------------------------------------------------------------------
            IF @DEBUG & 0x01 <> 0 BEGIN
                -- SELECT [@Now] = @Now, [@StartDateTime] = @StartDateTime
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'')
                                    + QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName)
                                    + N' End point <<' + Convert(NVarChar(20), DateAdd(ms, DateDiff(ms, @StartDateTime, @Now), Cast('00:00:00' AS Time(3))), 114) + '>> (Ret:' + IsNull(Cast(@Return AS NVarChar(20)), N'NULL') + N')' + IsNull(N' /' + @Error + N'/', N'') + N'.';
                PRINT (@PrintMessage);
            END;

            IF @DEBUG & 0x02 <> 0 BEGIN
                SELECT
                    [DebugInfo.Finish]  = QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName),
                    ----
                    [@Return]   = @Return,
                    [@Error]    = @Error
            END
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        RETURN (0);
    ----------------------------------------------------------------------------
    END TRY
    BEGIN CATCH
    ----------------------------------------------------------------------------
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID;
    ----------------------------------------------------------------------------
    END CATCH;
    ----------------------------------------------------------------------------

GO

/****** Object:  StoredProcedure [Debug].[Execution@Point]    Script Date: 04/11/2018 16:31:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--==================================================================================================
-- <Назначение>:        Сохранение точки логирования процедуры;
-- <Версия>:            v3.0;
-- <Дата>:              23.06.2016;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       ;
----------------------------------------------------------------------------------------------------
-- <Версия>:            v4.0;
-- <Дата>:              07.01.2018;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       С использованием Extended Events;
---=================================================================================================
CREATE PROCEDURE [Debug].[Execution@Point]
    @Proc_Id                    Int,
    @DebugContext               TParams             OUT,
    @Comment                    NVarChar(1024),
    @RowCount                   Int                 = NULL,
    @Values                     [Debug].[Params]    READONLY
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    DECLARE
        @Event_Id                   Int                 = 82,   -- Пока зашиваем жестко!

        @DEBUG                      TinyInt,                    -- Bit-маска режима отладки
                                                                -- 0x01 -- вывод таймингов
                                                                -- 0x02 -- вывод значений переменных
                                                                -- 0x04 -- вывод табличных данных

        @DbName                     SysName             = Db_Name(),
        @ObjectSchema               SysName,
        @ObjectName                 SysName,

        @PrintMessage               NVarChar(1024),
        @Execution_Id               BigInt,
        @StartDateTime              DateTime2(3),
        @DateTime                   DateTime2(3),
        @SubDateTime                DateTime2(3),
        @LastIndex                  Int,
        @Now                        DateTime2(3),
        
        @EventInfo                  NVarChar(128),
        @EventParamsData            NVarChar(Max)       = NULL,
        @EventParamsDataLen         Int                 = NULL,
        @PrmEventsCount             Int                 = 0,
        @PrmIndex                   Int                 = 0,

        @EventJData                 NVarChar(4000),
        @EventData                  VarBinary(8000);

    ----------------------------------------------------------------------------
    BEGIN TRY
    ----------------------------------------------------------------------------
        -- Проверка параметров
        ------------------------------------------------------------------------
        IF @Proc_Id IS NULL
            RaisError('DEBUG ERROR: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Execution@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @ObjectSchema   = Object_Schema_Name(@Proc_Id);
        SET @ObjectName     = Object_Name(@Proc_Id);

        IF @ObjectSchema IS NULL OR @ObjectName IS NULL
            RaisError('DEBUG ERROR: Invalid @Proc_Id = %i', 16, 2, @Proc_Id);

        IF @DebugContext IS NULL
            RaisError('DEBUG ERROR: @DebugContext IS NULL', 16, 2);

        SELECT
            @Now                = SysDateTime(),
            @DEBUG              = Cast([System].[Session Variable]('DEBUG') AS TinyInt);

        SELECT
            @Execution_Id       = @DebugContext.AsBigInt('Execution_Id'),
            @DateTime           = @DebugContext.AsDateTime2('DateTime'),
            @SubDateTime        = @DebugContext.AsDateTime2('SubDateTime'),
            @LastIndex          = @DebugContext.AsInt('LastIndex') + 1;

        ------------------------------------------------------------------------
        -- Готовим Json со всеми параметрами
        ------------------------------------------------------------------------
        IF EXISTS(SELECT TOP (1) 1 FROM @Values) BEGIN
            SET @EventParamsData    =
                (
                    SELECT
                        [Index]     = V.[Index],
                        [Name]      = V.[Name],
                        [Value]     = V.[Value]
                    FROM @Values V
                    FOR JSON AUTO
                );
            SET @EventParamsDataLen = Len(@EventParamsData);
            SET @PrmEventsCount     = @EventParamsDataLen / 4000
                                    + CASE WHEN @EventParamsDataLen % 4000 > 0 THEN 1 ELSE 0 END;
        END;

        ------------------------------------------------------------------------
        -- Формируем событие (Extended Event) для факта вызова
        ------------------------------------------------------------------------
        SET @EventInfo  =
            (
                SELECT
                    [Kind]      = 'Point',
                    [Id]        = @Execution_Id,
                    [Index]     = @LastIndex,
                    [EType]     = 'Info',
                    [PrmEvents] = IsNull(@PrmEventsCount, 0)
                FOR JSON PATH
            );

        SET @EventJData =   (
                                SELECT
                                    [SpId]              = @@SpId,
                                    [Object_Id]         = @Proc_Id,
                                    [DateTime]          = @DateTime,
                                    [Duration]          = DateDiff(MilliSecond, @DateTime, @Now),
                                    [Rows]              = @RowCount,
                                    [TranCount]         = @@TranCount,
                                    [Comment]           = @Comment
                                FOR JSON PATH
                            );
        SET @EventData  =   Cast(@EventJData AS VarBinary(8000));

        ------------------------------------------------------------------------
        EXEC [sys].[sp_trace_generateevent]
            @eventid    = @Event_Id,
            @userinfo   = @EventInfo,
            @userdata   = @EventData;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        IF @EventParamsData IS NOT NULL BEGIN
        ------------------------------------------------------------------------
            -- Формируем события (Extended Event) для сохранения значений параметров
            --------------------------------------------------------------------
            SET @PrmIndex = 1;
            WHILE @PrmIndex <= @PrmEventsCount BEGIN
            --------------------------------------------------------------------
                SET @EventData  =   Cast
                                    (
                                        SubString(@EventParamsData, (@PrmIndex-1)* 4000, 4000)
                                        AS VarBinary(8000)
                                    );

                SET @EventInfo  =
                    (
                        SELECT
                            [Kind]          = 'Point',
                            [Id]            = @Execution_Id,
                            [Index]         = @LastIndex,
                            [EType]         = 'PrmSection',
                            [EIndex]        = @PrmIndex,
                            [IsLast]        = CASE WHEN @PrmIndex = @PrmEventsCount THEN Cast(1 AS Bit) END
                        FOR JSON PATH
                    );

                EXEC [sys].[sp_trace_generateevent]
                    @eventid    = @Event_Id,
                    @userinfo   = @EventInfo,
                    @userdata   = @EventData;


                SET @PrmIndex += 1;
            --------------------------------------------------------------------
            END;
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        -- Формируем @DebugContext
        ------------------------------------------------------------------------
        SET @DebugContext.AddParam('DateTime', @Now);
        SET @DebugContext.AddParam('SubDateTime', @Now);
        SET @DebugContext.AddParam('LastIndex', @LastIndex);

        ------------------------------------------------------------------------
        IF @DEBUG <> 0 BEGIN
        ------------------------------------------------------------------------
            -- Вывод таймингов + параметров
            ------------------------------------------------------------------------
            IF @DEBUG & 0x01 <> 0 BEGIN
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'')
                                    + N'..' + QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName)
                                    + N' (' + IsNull(Convert(NVarChar(20), DateAdd(ms, DateDiff(ms, @DateTime, @Now), Cast('00:00:00' AS Time(3))), 114), 'NULL') + ') [' + IsNull(Cast(@RowCount AS NVarChar(20)), N'NULL') + N']: ' + IsNull(@Comment, N'');
                PRINT (@PrintMessage);
            END;
            IF @DEBUG & 0x02 <> 0 BEGIN
                SELECT
                    [DebugInfo.Point]   = QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName),
                    [Comment]           = @Comment,
                    ----
                    [Values1.Name]      = V1.[Name],
                    [Values1.Value]     = V1.[Value],
                    [Values2.Name]      = V2.[Name],
                    [Values2.Value]     = V2.[Value],
                    [Values3.Name]      = V3.[Name],
                    [Values3.Value]     = V3.[Value],
                    [Values4.Name]      = V4.[Name],
                    [Values4.Value]     = V4.[Value],
                    [Values5.Name]      = V5.[Name],
                    [Values5.Value]     = V5.[Value],
                    [Values6.Name]      = V6.[Name],
                    [Values6.Value]     = V6.[Value],
                    [Values7.Name]      = V7.[Name],
                    [Values7.Value]     = V7.[Value],
                    [Values8.Name]      = V8.[Name],
                    [Values8.Value]     = V8.[Value]
                FROM (VALUES (NULL)) R ([Null])
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 1) V1
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 2) V2
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 3) V3
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 4) V4
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 5) V5
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 6) V6
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 7) V7
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 8) V8;
            END;
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        RETURN (0);
    ----------------------------------------------------------------------------
    END TRY
    BEGIN CATCH
    ----------------------------------------------------------------------------
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID;
    ----------------------------------------------------------------------------
    END CATCH;
    ----------------------------------------------------------------------------

GO

/****** Object:  StoredProcedure [Debug].[Execution@Read]    Script Date: 04/11/2018 16:31:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Debug].[Execution@Read]
    @ObjectName             SysName             = NULL,     -- Процедура
    @LogSessionCount        Int                 = 1,        -- На какое количество последних сессий возвращаем результат
    @Expand                 Bit                 = 1,
    @WithChilds             Bit                 = 1,
    @HostName               VarChar(2000)       = NULL,     -- Фильтровать по хосту, задаем целиком
    @Who                    VarChar(2000)       = NULL,
    @BeginDate              DateTime2           = NULL,
    @EndDate                DateTime2           = NULL,
    @ParamName              SysName             = NULL,
    @ParamValue             NVarChar(Max)       = NULL,
    @Exec_IDs               NVarChar(Max)       = NULL
------
    WITH EXECUTE AS OWNER
------
AS
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE
        @CMaxInt        Int           = 2147483647;

    DECLARE
        @Object_Id      Int,
        @Database       SysName,
        @Schema         Sysname,
        @Object         Sysname,
        @BaseNestLevel  Int;

    DECLARE @IDsX       [Table].[(BigInt)];

    DECLARE @IDs Table
    (
        [Id]            BigInt          NOT NULL,
        [TopParent_Id]  BigInt          NOT NULL,
        [Parent_Id]     BigInt              NULL,
        [Proc_Id]       Int                 NULL,
        [NestLevel]     Int                 NULL,
        [ObjectName]    NVarChar(512)       NULL,
        [SpId]          Int                 NULL,
        PRIMARY KEY CLUSTERED ([Id])
    );

    --табличная переменная - задел под вывод результатов в строковом виде, чтобы избежать дублирования кода
    DECLARE @Result Table
    (
        [TopParent_Id]  BigInt          NOT NULL,
        [Exec_Id]       BigInt          NOT NULL,
        [Parent_Id]     BigInt              NULL,
        [NestLevel]     TinyInt             NULL,
        [Index]         Int                 NULL,
        [Kind]          Char(1)         NOT NULL,
        [SpId]          Int                 NULL,
        [DateTime]      DateTime2       NOT NULL,
        [Duration]      Numeric(12,3)       NULL,
        [Text]          NVarChar(Max)       NULL,
        [RowCount]      Int                 NULL,
        [TranCount]     SmallInt            NULL,
        [Param1.Name]   SysName             NULL,
        [Param1.Value]  NVarChar(Max)       NULL,
        [Param2.Name]   SysName             NULL,
        [Param2.Value]  NVarChar(Max)       NULL,
        [Param3.Name]   SysName             NULL,
        [Param3.Value]  NVarChar(Max)       NULL,
        [Param4.Name]   SysName             NULL,
        [Param4.Value]  NVarChar(Max)       NULL,
        [Param5.Name]   SysName             NULL,
        [Param5.Value]  NVarChar(Max)       NULL,
        [Param6.Name]   SysName             NULL,
        [Param6.Value]  NVarChar(Max)       NULL,
        [OtherParams]   NVarChar(Max)       NULL,
        [AfterExec_Id]  BigInt              NULL,
        UNIQUE CLUSTERED([TopParent_Id], [DateTime], [Exec_Id], [NestLevel] DESC, [Index])
    );

    IF @ObjectName IS NOT NULL BEGIN
        SET @Object_Id  = Object_Id(@ObjectName);
        IF @Object_Id IS NULL BEGIN
            Raiserror('Объект не найден: %s', 16, 1, @ObjectName);
            RETURN (0);
        END;

        SET @Database   = IsNull(ParseName(@ObjectName, 3), Db_Name());
        SET @Schema     = Object_Schema_Name(@Object_Id);
        SET @Object     = Object_Name(@Object_Id);
    END;

    IF @Exec_IDs IS NOT NULL BEGIN
        SET @Exec_IDs   = NullIf(Replace(Replace(Replace(Replace(Replace(Replace(Replace(Replace(Replace(@Exec_IDs, ' ', ','), Char(10), ','), Char(13), ','), Char(8), ','), ';', ','), ',,', ','), ',,', ','), ',,', ','), ',,', ','), '');

        INSERT INTO @IDsX
        SELECT
            [Value]
        FROM
        (
            SELECT
                [Value] = Try_Cast(X.[Value] AS BigInt)
            FROM [Pub].[Array To RowSet Of Values](@Exec_IDs, ',') X
            WHERE   X.[Value] IS NOT NULL
                AND NullIf([Pub].[Trim](X.[Value], N' '), N'') IS NOT NULL
        ) X;
    END;

    -- Поиск Id процедур, по которым надо выводить результаты (в т.ч. вложенных)
    WITH Tree AS
    (
        SELECT TOP (@LogSessionCount)
            [Id]            = P.[Id],
            [TopParent_Id]  = P.[Id],
            [Parent_Id]     = P.[Parent_Id],
            [Proc_Id]       = P.[Object_Id],
            [NestLevel]     = P.[NestLevel],
            [Database]      = P.[Database],
            [Schema]        = P.[Schema],
            [Object]        = P.[Object],
            [SpId]          = P.[SpId]
        FROM [Debug].[Execution:Start]  AS P
        WHERE   (@Exec_IDs IS NULL OR P.[Id] IN (SELECT [Id] FROM @IDsX))
            AND (@Database IS NULL OR P.[Database] = @Database)
            AND (@Schema IS NULL OR @Object IS NULL OR P.[Schema] = @Schema AND P.[Object] = @Object)
            AND (@Who IS NULL OR P.[UserName] = @Who OR P.[LoginName] = @Who)
            AND (@BeginDate IS NULL OR P.[StartDateTime] >= @BeginDate)
            AND (@EndDate IS NULL OR P.[StartDateTime] <= @EndDate)
            AND (   @ParamName IS NULL
                OR  (
                        @ParamName IS NOT NULL
                    AND EXISTS
                        (
                            SELECT TOP (1) 1
                            FROM [Debug].[Execution:Start:Params] PRM
                            WHERE   PRM.[Name] = @ParamName
                                AND (   (@ParamValue IS NULL AND PRM.[Value] IS NULL)
                                    OR  (PRM.[Value] = @ParamValue)
                                    )
                        )
                    )
                )
        ORDER BY P.[StartDateTime] DESC
        ---
        UNION ALL
        ---
        SELECT
            [Id]            = C.[Id],
            [TopParent_Id]  = T.[TopParent_Id],
            [Parent_Id]     = C.[Parent_Id],
            [Proc_Id]       = C.[Object_Id],
            [NestLevel]     = C.[NestLevel],
            [Database]      = C.[Database],
            [Schema]        = C.[Schema],
            [Object]        = C.[Object],
            [SpId]          = C.[SpId]
        FROM [Debug].[Execution:Start]  C
        INNER JOIN Tree                 T ON T.[Id] = C.[Parent_Id]
        WHERE @WithChilds = 1
    )
    INSERT INTO @IDs ([Id], [TopParent_Id], [Parent_Id], [Proc_Id], [NestLevel], [ObjectName])
    SELECT
        [Id], [TopParent_Id], [Parent_Id], [Proc_Id], [NestLevel], QuoteName([Database]) + N'.' + QuoteName([Schema]) + N'.' + Quotename([Object])
    FROM Tree
    OPTION (RECOMPILE);

    SELECT TOP (1)
        @BaseNestLevel  = [NestLevel]
    FROM @IDs
    ORDER BY [Id] ASC;

    ----------------------------------------------------------------------------
    IF @Expand = 1 BEGIN
    ----------------------------------------------------------------------------
        INSERT INTO @Result
        SELECT *
        FROM
        (
            SELECT
                [TopParent_Id]          = IDs.[TopParent_Id],
                [Exec_Id]               = IDs.[Id],
                [Parent_Id]             = IDs.[Parent_Id],
                [NestLevel]             = IDs.[NestLevel],
                [Index]                 = 0,
                [Kind]                  = 'S',
                [SpId]                  = IDs.[SpId],
                [DateTime]              = S.[StartDateTime],
                [Duration]              = Cast(NULL AS Numeric(12,3)),
                [Text]                  = Space((IDs.[NestLevel] - @BaseNestLevel) * 2) + '<--------------- START (' + IsNull(IDs.[ObjectName], 'NULL') + ')',
                [RowCount]              = NULL,
                [TranCount]             = S.[TranCount],
                [Param1.Name]           = P1.[Name],
                [Param1.Value]          = P1.[Value],
                [Param2.Name]           = P2.[Name],
                [Param2.Value]          = P2.[Value],
                [Param3.Name]           = P3.[Name],
                [Param3.Value]          = P3.[Value],
                [Param4.Name]           = P4.[Name],
                [Param4.Value]          = P4.[Value],
                [Param5.Name]           = P5.[Name],
                [Param5.Value]          = P5.[Value],
                [Param6.Name]           = P6.[Name],
                [Param6.Value]          = P6.[Value],
                [OtherParams]           = OP.[OtherParams],
                [AfterExec_Id]          = NULL
            FROM [Debug].[Execution:Start]      AS S
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 1
            )                                   AS P1
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 2
            )                                   AS P2
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 3
            )                                   AS P3
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 4
            )                                   AS P4
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 5
            )                                   AS P5
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 6
            )                                   AS P6
            INNER JOIN @IDs                     AS IDs ON IDs.[Id] = S.[Id]
            OUTER APPLY
            (
                SELECT
                    [OtherParams]       = [Pub].[Concat](OP.[Name] + '=' + OP.[Value], '; ')
                FROM [Debug].[Execution:Start:Params]   OP
                WHERE   OP.[Id] = S.[Id]
                    AND OP.[Index] > 6
            )                                   AS OP
            ---
            UNION ALL
            ---
            SELECT
                [TopParent_Id]          = IDs.[TopParent_Id],
                [Exec_Id]               = IDs.[Id],
                [Parent_Id]             = IDs.[Parent_Id],
                [NestLevel]             = IDs.[NestLevel],
                [Index]                 = NULL, -- @CMaxInt,
                [Kind]                  = 'F',
                [SpId]                  = IDs.[SpId],
                [DateTime]              = F.[EndDateTime],
                [Duration]              = Cast(F.[Duration] / 1000.0 AS Numeric(12,3)),
                [Text]                  = Space((IDs.[NestLevel] - @BaseNestLevel) * 2) + '---------------> END OF (' + IsNull(IDs.[ObjectName], 'NULL') + ')',
                [RowCount]              = NULL,
                [TranCount]             = F.[TranCount],
                [Param1.Name]           = 'Return',
                [Param1.Value]          = Cast(F.[Return] AS NVarChar(20)),
                [Param2.Name]           = 'Error',
                [Param2.Value]          = F.[Error],
                [Param3.Name]           = NULL,
                [Param3.Value]          = NULL,
                [Param4.Name]           = NULL,
                [Param4.Value]          = NULL,
                [Param5.Name]           = NULL,
                [Param5.Value]          = NULL,
                [Param6.Name]           = NULL,
                [Param6.Value]          = NULL,
                [OtherParams]           = NULL,
                [AfterExec_Id]          = NULL
            FROM [Debug].[Execution:Finish]       F
            INNER JOIN @IDs                       IDs ON IDs.[Id] = F.[Id]
            ---
            UNION ALL
            ---
            SELECT
                [TopParent_Id]          = IDs.[TopParent_Id],
                [Exec_Id]               = IDs.[Id],
                [Parent_Id]             = IDs.[Parent_Id],
                [NestLevel]             = IDs.[NestLevel],
                [Index]                 = S.[Index],
                [Kind]                  = S.[Kind],
                [SpId]                  = IDs.[SpId],
                [DateTime]              = S.[DateTime],
                [Duration]              = Cast(S.[Duration] / 1000.0 AS Numeric(12,3)),
                [Text]                  = Space((IDs.[NestLevel] - @BaseNestLevel) * 2) + '  ' + CASE WHEN S.[Kind] = 'p' THEN '--' ELSE '' END + S.[Comment],
                [RowCount]              = S.[Rows],
                [TranCount]             = S.[TranCount],
                [Param1.Name]           = S.[Value1.Name],
                [Param1.Value]          = S.[Value1.Value],
                [Param2.Name]           = S.[Value2.Name],
                [Param2.Value]          = S.[Value2.Value],
                [Param3.Name]           = S.[Value3.Name],
                [Param3.Value]          = S.[Value3.Value],
                [Param4.Name]           = S.[Value4.Name],
                [Param4.Value]          = S.[Value4.Value],
                [Param5.Name]           = NULL,
                [Param5.Value]          = NULL,
                [Param6.Name]           = NULL,
                [Param6.Value]          = NULL,
                [OtherParams]           = OV.[OtherParams],
                [AfterExec_Id]          = S.[AfterExec_Id]
            FROM [Debug].[Execution:Stmt]         AS S
            INNER JOIN @IDs                       AS IDs    ON IDs.[Id] = S.[Exec_Id]
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Stmt:Params]    AS P
                WHERE   P.[Exec_Id] = S.[Exec_Id]
                    AND P.[Stmt_Index] = S.[Index]
                    AND P.[Index] = 1
            )                                   AS P1
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Stmt:Params]    AS P
                WHERE   P.[Exec_Id] = S.[Exec_Id]
                    AND P.[Stmt_Index] = S.[Index]
                    AND P.[Index] = 2
            )                                   AS P2
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Stmt:Params]    AS P
                WHERE   P.[Exec_Id] = S.[Exec_Id]
                    AND P.[Stmt_Index] = S.[Index]
                    AND P.[Index] = 3
            )                                   AS P3
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Stmt:Params]    AS P
                WHERE   P.[Exec_Id] = S.[Exec_Id]
                    AND P.[Stmt_Index] = S.[Index]
                    AND P.[Index] = 4
            )                                   AS P4
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Stmt:Params]    AS P
                WHERE   P.[Exec_Id] = S.[Exec_Id]
                    AND P.[Stmt_Index] = S.[Index]
                    AND P.[Index] = 5
            )                                   AS P5
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Stmt:Params]    AS P
                WHERE   P.[Exec_Id] = S.[Exec_Id]
                    AND P.[Stmt_Index] = S.[Index]
                    AND P.[Index] = 6
            )                                   AS P6
            OUTER APPLY
            (
                SELECT
                [OtherParams]       = [Pub].[Concat](OV.[Name] + '=' + OV.[Value], '; ')
                FROM [Debug].[Execution:Stmt:Params]    OV
                WHERE   OV.[Exec_Id] = S.[Exec_Id]
                    AND OV.[Stmt_Index] = S.[Index]
                    AND OV.[Index] > 6
            )                                   AS OV
        ) R
        OPTION (RECOMPILE);

        UPDATE R SET
            R.[AfterExec_Id]    = RI.[AfterExec_Id]
        FROM @Result        R
        CROSS APPLY
        (
            SELECT TOP (1)
                RI.[AfterExec_Id]
            FROM @Result RI
            WHERE   RI.[TopParent_Id] = R.[TopParent_Id]
                AND RI.[DateTime] = R.[DateTime]
                AND RI.[Exec_Id] = R.[Exec_Id]
                AND RI.[AfterExec_Id] IS NOT NULL
        ) RI;

        UPDATE R SET
            R.[AfterExec_Id]    = AE.[Exec_Id]
        FROM  @Result R
        CROSS APPLY
        (
            SELECT TOP (1)
                RI.[Exec_Id]
            FROM @Result RI
            WHERE   RI.[TopParent_Id] = R.[TopParent_Id]
                AND RI.[DateTime] = R.[DateTime]
                AND RI.[Kind] = 'F'
                AND RI.[Parent_Id] = R.[Exec_Id]
            ORDER BY RI.[Exec_Id] DESC
        ) AE
        WHERE   R.[Kind] = 'F'
            AND R.[AfterExec_Id] IS NULL;
            --AND NOT EXISTS
            --    (
            --        SELECT TOP (1) 1
            --        FROM @Result RX
            --        WHERE RX.[TopParent_Id] = R.[TopParent_Id] AND RX.[DateTime] = R.[DateTime] AND RX.[Exec_Id] = R.[Exec_Id] AND RX.[Kind] <> 'F' AND RX.[AfterExec_Id] IS NOT NULL
            --    );

        ------------------------------------------------------------------------
        -- Вывод результата
        ------------------------------------------------------------------------
        SELECT
            R.*
        FROM @Result R
        ORDER BY
            [TopParent_Id] DESC,
            [DateTime],
            CASE
                WHEN [AfterExec_Id] IS NULL
                    THEN NULL
                ELSE -[AfterExec_Id]
            END,
            [Exec_Id],
            [NestLevel] DESC,
            IsNull([Index], @CMaxInt);
    ----------------------------------------------------------------------------
    END ELSE BEGIN
    ----------------------------------------------------------------------------
        -- Вывод результата
        ------------------------------------------------------------------------
        SELECT *
        FROM
        (
            SELECT
                [TopParent_Id]          = IDs.[TopParent_Id],
                [Exec_Id]               = IDs.[Id],
                [Parent_Id]             = IDs.[Parent_Id],
                [NestLevel]             = IDs.[NestLevel],
                [Index]                 = NULL,
                [Kind]                  = 'E',
                [SpId]                  = S.[SpId],
                [DateTime]              = S.[StartDateTime],
                [Duration]              = Cast(F.[Duration] / 1000.0 AS Numeric(12,3)),
                [Text]                  = Space((IDs.[NestLevel] - @BaseNestLevel) * 2) + IsNull(IDs.[ObjectName], 'NULL'),
                [Return]                = F.[Return],
                [Error]                 = F.[Error],
                [Start:TranCount]       = S.[TranCount],
                [Finish:TranCount]      = F.[TranCount],
                [Param1.Name]           = P1.[Name],
                [Param1.Value]          = P1.[Value],
                [Param2.Name]           = P2.[Name],
                [Param2.Value]          = P2.[Value],
                [Param3.Name]           = P3.[Name],
                [Param3.Value]          = P3.[Value],
                [Param4.Name]           = P4.[Name],
                [Param4.Value]          = P4.[Value],
                [Param5.Name]           = P5.[Name],
                [Param5.Value]          = P5.[Value],
                [Param6.Name]           = P6.[Name],
                [Param6.Value]          = P6.[Value],
                [OtherParams]           = OP.[OtherParams]
            FROM @IDs                               AS IDs
            INNER JOIN [Debug].[Execution:Start]    AS S   ON S.[Id] = IDs.[Id]
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 1
            )                                       AS P1
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 2
            )                                       AS P2
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 3
            )                                       AS P3
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 4
            )                                       AS P4
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 5
            )                                       AS P5
            OUTER APPLY
            (
                SELECT
                    P.[Name],
                    P.[Value]
                FROM [Debug].[Execution:Start:Params]   AS P
                WHERE   P.[Id] = S.[Id]
                    AND P.[Index] = 6
            )                                       AS P6
            INNER JOIN [Debug].[Execution:Finish]   AS F   ON F.[Id] = IDs.[Id]
            OUTER APPLY
            (
                SELECT
                    [OtherParams]       = [Pub].[Concat](OP.[Name] + '=' + OP.[Value], '; ')
                FROM [Debug].[Execution:Start:Params]   OP
                WHERE   OP.[Id] = S.[Id]
                    AND OP.[Index] > 6
            )                                   AS OP
        ) AS R
        ORDER BY
            [TopParent_Id] DESC,
            [DateTime],
            [Exec_Id],
            [NestLevel] DESC
        OPTION (RECOMPILE);
    ----------------------------------------------------------------------------
    END;
    ----------------------------------------------------------------------------

    RETURN (0);

GO

/****** Object:  StoredProcedure [Debug].[Execution@Start]    Script Date: 04/11/2018 16:31:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--==================================================================================================
-- <Назначение>:        Процедура начала логирования процедуры;
-- <Версия>:            v3.0;
-- <Дата>:              22.06.2016;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       ;
----------------------------------------------------------------------------------------------------
-- <Версия>:            v4.0;
-- <Дата>:              07.01.2018;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       С использованием Extended Events;
---=================================================================================================
CREATE PROCEDURE [Debug].[Execution@Start]
    @Proc_Id                    Int,
    @DebugContext               TParams             OUT,
    @Params                     [Debug].[Params]    READONLY
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    DECLARE
        @Event_Id                   Int                 = 82,   -- Пока зашиваем жестко!

        @DEBUG                      TinyInt,                    -- Bit-маска режима отладки
                                                                -- 0x01 -- вывод таймингов
                                                                -- 0x02 -- вывод значений переменных
                                                                -- 0x04 -- вывод табличных данных

        @DbName                     SysName             = Db_Name(),
        @ObjectSchema               SysName,
        @ObjectName                 SysName,

        @PrintMessage               NVarChar(1024),
        @Execution_Id               BigInt,
        @StartDateTime              DateTime2(3),
        
        @EventInfo                  NVarChar(128),
        @EventParamsData            NVarChar(Max)       = NULL,
        @EventParamsDataLen         Int                 = NULL,
        @PrmEventsCount             Int                 = 0,
        @PrmIndex                   Int                 = 0,

        @EventJData                 NVarChar(4000),
        @EventData                  VarBinary(8000);

    ----------------------------------------------------------------------------
    BEGIN TRY
    ----------------------------------------------------------------------------
        -- Проверка параметров
        ------------------------------------------------------------------------
        IF @Proc_Id IS NULL
            RaisError('DEBUG ERROR: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Execution@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @ObjectSchema   = Object_Schema_Name(@Proc_Id);
        SET @ObjectName     = Object_Name(@Proc_Id);

        IF @ObjectSchema IS NULL OR @ObjectName IS NULL
            RaisError('DEBUG ERROR: Invalid @Proc_Id = %i', 16, 2, @Proc_Id);

        SELECT
            @StartDateTime      = SysDateTime(),
            @Execution_Id       = (NEXT VALUE FOR [CIS.Log].[Debug].[Execution:Id]),
            @DEBUG              = Cast([System].[Session Variable]('DEBUG') AS TinyInt);

        ------------------------------------------------------------------------
        -- Формируем @DebugContext
        ------------------------------------------------------------------------
        SET @DebugContext   = TParams::New()
                                .[Add]('Execution_Id',      @Execution_Id)
                                .[Add]('StartDateTime',     @StartDateTime)
                                .[Add]('DateTime',          @StartDateTime)
                                .[Add]('SubDateTime',       @StartDateTime)
                                .[Add]('LastIndex',         0);
                
        ------------------------------------------------------------------------
        -- Готовим Json со всеми параметрами
        ------------------------------------------------------------------------
        IF EXISTS(SELECT TOP (1) 1 FROM @Params) BEGIN
            SET @EventParamsData    =
                (
                    SELECT
                        [Index]     = P.[Index],
                        [Name]      = P.[Name],
                        [Value]     = P.[Value]
                    FROM @Params P
                    FOR JSON AUTO
                );
            SET @EventParamsDataLen = Len(@EventParamsData);
            SET @PrmEventsCount     = @EventParamsDataLen / 4000
                                    + CASE WHEN @EventParamsDataLen % 4000 > 0 THEN 1 ELSE 0 END;
        END;

        ------------------------------------------------------------------------
        -- Формируем событие (Extended Event) для факта вызова
        ------------------------------------------------------------------------
        SET @EventInfo  =
            (
                SELECT
                    [Kind]      = 'Start',
                    [Id]        = @Execution_Id,
                    [EType]     = 'Info',
                    [PrmEvents] = IsNull(@PrmEventsCount, 0)
                FOR JSON PATH
            );
        SET @EventJData =   (
                                SELECT
                                    [SpId]              = @@SpId,
                                    [Database]          = @DbName,
                                    [ObjectSchema]      = @ObjectSchema,
                                    [ObjectName]        = @ObjectName,
                                    [Object_Id]         = @Proc_Id,
                                    [DateTime]          = @StartDateTime,
                                    [NestLevel]         = @@NestLevel - 1,
                                    [LoginName]         = Original_Login(),
                                    [UserName]          = User_Name(),
                                    [HostName]          = Host_Name(),
                                    [TranCount]         = @@TranCount,
                                    [ConnectionGUId]    = [System].[Connection@GUId]()
                                FOR JSON PATH
                            );
        SET @EventData  =   Cast(@EventJData AS VarBinary(8000));

        ------------------------------------------------------------------------
        EXEC [sys].[sp_trace_generateevent]
            @eventid    = @Event_Id,
            @userinfo   = @EventInfo,
            @userdata   = @EventData;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        IF @EventParamsData IS NOT NULL BEGIN
        ------------------------------------------------------------------------
            -- Формируем события (Extended Event) для сохранения значений параметров
            --------------------------------------------------------------------
            SET @PrmIndex = 1;
            WHILE @PrmIndex <= @PrmEventsCount BEGIN
            --------------------------------------------------------------------
                SET @EventData  =   Cast
                                    (
                                        SubString(@EventParamsData, (@PrmIndex-1)* 4000, 4000)
                                        AS VarBinary(8000)
                                    );

                SET @EventInfo  =
                    (
                        SELECT
                            [Kind]          = 'Start',
                            [Id]            = @Execution_Id,
                            [EType]         = 'PrmSection',
                            [EIndex]        = @PrmIndex,
                            [IsLast]        = CASE WHEN @PrmIndex = @PrmEventsCount THEN Cast(1 AS Bit) END
                        FOR JSON PATH
                    );

                EXEC [sys].[sp_trace_generateevent]
                    @eventid    = @Event_Id,
                    @userinfo   = @EventInfo,
                    @userdata   = @EventData;

                SET @PrmIndex += 1;
            --------------------------------------------------------------------
            END;
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        IF @DEBUG <> 0 BEGIN
        ------------------------------------------------------------------------
            -- Вывод таймингов + параметров
            --------------------------------------------------------------------
            IF @DEBUG & 0x01 <> 0 BEGIN
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'') + QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName) + N' Start point. ----------------------------------------';
                PRINT (@PrintMessage);
            END
            IF @DEBUG & 0x02 <> 0 BEGIN
                SELECT
                    [DebugInfo.Start]   = QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName),
                    ----
                    [Param1.Name]   = P1.[Name],
                    [Param1.Value]  = P1.[Value],
                    [Param2.Name]   = P2.[Name],
                    [Param2.Value]  = P2.[Value],
                    [Param3.Name]   = P3.[Name],
                    [Param3.Value]  = P3.[Value],
                    [Param4.Name]   = P4.[Name],
                    [Param4.Value]  = P4.[Value],
                    [Param5.Name]   = P5.[Name],
                    [Param5.Value]  = P5.[Value],
                    [Param6.Name]   = P6.[Name],
                    [Param6.Value]  = P6.[Value],
                    [Param7.Name]   = P7.[Name],
                    [Param7.Value]  = P7.[Value],
                    [Param8.Name]   = P8.[Name],
                    [Param8.Value]  = P8.[Value]
                FROM (VALUES (NULL)) R([Null])
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 1) P1
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 2) P2
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 3) P3
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 4) P4
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 5) P5
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 6) P6
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 7) P7
                OUTER APPLY (SELECT TOP (1) * FROM @Params WHERE [Index] = 8) P8;
            END;
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        RETURN (0);
    ----------------------------------------------------------------------------
    END TRY
    BEGIN CATCH
    ----------------------------------------------------------------------------
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID
    ----------------------------------------------------------------------------
    END CATCH;
    ----------------------------------------------------------------------------

GO

/****** Object:  StoredProcedure [Debug].[Execution@SubPoint]    Script Date: 04/11/2018 16:31:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--==================================================================================================
-- <Назначение>:        Сохранение суб-точки логирования процедуры;
-- <Версия>:            v3.0;
-- <Дата>:              23.06.2016;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       ;
----------------------------------------------------------------------------------------------------
-- <Версия>:            v4.0;
-- <Дата>:              07.01.2018;
-- <Автор>:             Gagarkin;
-- <Комментарий>:       С использованием Extended Events;
---=================================================================================================
CREATE PROCEDURE [Debug].[Execution@SubPoint]
    @Proc_Id                    Int,
    @DebugContext               TParams             OUT,
    @Comment                    NVarChar(1024),
    @RowCount                   Int                 = NULL,
    @Values                     [Debug].[Params]    READONLY
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    DECLARE
        @Event_Id                   Int                 = 82,   -- Пока зашиваем жестко!

        @DEBUG                      TinyInt,                    -- Bit-маска режима отладки
                                                                -- 0x01 -- вывод таймингов
                                                                -- 0x02 -- вывод значений переменных
                                                                -- 0x04 -- вывод табличных данных

        @DbName                     SysName             = Db_Name(),
        @ObjectSchema               SysName,
        @ObjectName                 SysName,

        @PrintMessage               NVarChar(1024),
        @Execution_Id               BigInt,
        @StartDateTime              DateTime2(3),
        @DateTime                   DateTime2(3),
        @SubDateTime                DateTime2(3),
        @LastIndex                  Int,
        @Now                        DateTime2(3),
        
        @EventInfo                  NVarChar(128),
        @EventParamsData            NVarChar(Max)       = NULL,
        @EventParamsDataLen         Int                 = NULL,
        @PrmEventsCount             Int                 = 0,
        @PrmIndex                   Int                 = 0,

        @EventJData                 NVarChar(4000),
        @EventData                  VarBinary(8000);

    ----------------------------------------------------------------------------
    BEGIN TRY
    ----------------------------------------------------------------------------
        -- Проверка параметров
        ------------------------------------------------------------------------
        IF @Proc_Id IS NULL
            RaisError('DEBUG ERROR: @Proc_Id IS NULL', 16, 2);

        IF [Debug].[Execution@Enabled](@Proc_Id) = 0
            RETURN (0);

        SET @ObjectSchema   = Object_Schema_Name(@Proc_Id);
        SET @ObjectName     = Object_Name(@Proc_Id);

        IF @ObjectSchema IS NULL OR @ObjectName IS NULL
            RaisError('DEBUG ERROR: Invalid @Proc_Id = %i', 16, 2, @Proc_Id);

        IF @DebugContext IS NULL
            RaisError('DEBUG ERROR: @DebugContext IS NULL', 16, 2);

        SELECT
            @Now                = SysDateTime(),
            @DEBUG              = Cast([System].[Session Variable]('DEBUG') AS TinyInt);

        SELECT
            @Execution_Id       = @DebugContext.AsBigInt('Execution_Id'),
            @DateTime           = @DebugContext.AsDateTime2('DateTime'),
            @SubDateTime        = @DebugContext.AsDateTime2('SubDateTime'),
            @LastIndex          = @DebugContext.AsInt('LastIndex') + 1;

        ------------------------------------------------------------------------
        -- Готовим Json со всеми параметрами
        ------------------------------------------------------------------------
        IF EXISTS(SELECT TOP (1) 1 FROM @Values) BEGIN
            SET @EventParamsData    =
                (
                    SELECT
                        [Index]     = V.[Index],
                        [Name]      = V.[Name],
                        [Value]     = V.[Value]
                    FROM @Values V
                    FOR JSON AUTO
                );
            SET @EventParamsDataLen = Len(@EventParamsData);
            SET @PrmEventsCount     = @EventParamsDataLen / 4000
                                    + CASE WHEN @EventParamsDataLen % 4000 > 0 THEN 1 ELSE 0 END;
        END;

        ------------------------------------------------------------------------
        -- Формируем событие (Extended Event) для факта вызова
        ------------------------------------------------------------------------
        SET @EventInfo  =
            (
                SELECT
                    [Kind]      = 'SubPoint',
                    [Id]        = @Execution_Id,
                    [Index]     = @LastIndex,
                    [EType]     = 'Info',
                    [PrmEvents] = IsNull(@PrmEventsCount, 0)
                FOR JSON PATH
            );

        SET @EventJData =   (
                                SELECT
                                    [SpId]              = @@SpId,
                                    [Object_Id]         = @Proc_Id,
                                    [DateTime]          = @DateTime,
                                    [Duration]          =  DateDiff(MilliSecond, @SubDateTime, @Now),
                                    [Rows]              = @RowCount,
                                    [TranCount]         = @@TranCount,
                                    [Comment]           = @Comment
                                FOR JSON PATH
                            );
        SET @EventData  =   Cast(@EventJData AS VarBinary(8000));

        ------------------------------------------------------------------------
        EXEC [sys].[sp_trace_generateevent]
            @eventid    = @Event_Id,
            @userinfo   = @EventInfo,
            @userdata   = @EventData;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        IF @EventParamsData IS NOT NULL BEGIN
        ------------------------------------------------------------------------
            -- Формируем события (Extended Event) для сохранения значений параметров
            --------------------------------------------------------------------
            SET @PrmIndex = 1;
            WHILE @PrmIndex <= @PrmEventsCount BEGIN
            --------------------------------------------------------------------
                SET @EventData  =   Cast
                                    (
                                        SubString(@EventParamsData, (@PrmIndex-1)* 4000, 4000)
                                        AS VarBinary(8000)
                                    );

                SET @EventInfo  =
                    (
                        SELECT
                            [Kind]          = 'SubPoint',
                            [Id]            = @Execution_Id,
                            [Index]         = @LastIndex,
                            [EType]         = 'PrmSection',
                            [EIndex]        = @PrmIndex,
                            [IsLast]        = CASE WHEN @PrmIndex = @PrmEventsCount THEN Cast(1 AS Bit) END
                        FOR JSON PATH
                    );

                EXEC [sys].[sp_trace_generateevent]
                    @eventid    = @Event_Id,
                    @userinfo   = @EventInfo,
                    @userdata   = @EventData;


                SET @PrmIndex += 1;
            --------------------------------------------------------------------
            END;
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        -- Формируем @DebugContext
        ------------------------------------------------------------------------
        SET @DebugContext.AddParam('SubDateTime', @Now);
        SET @DebugContext.AddParam('LastIndex', @LastIndex);

        ------------------------------------------------------------------------
        IF @DEBUG <> 0 BEGIN
        ------------------------------------------------------------------------
            -- Вывод таймингов + параметров
            ------------------------------------------------------------------------
            IF @DEBUG & 0x01 <> 0 BEGIN
                SET @PrintMessage = IsNull(Space((@@NestLevel - 2) * 4), N'')
                                    + '..--' + QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName)
                                    + N' /' + Convert(NVarChar(20), DateAdd(ms, DateDiff(ms, @SubDateTime, @Now), Cast('00:00:00' AS Time(3))), 114) + '/ [' + IsNull(Cast(@RowCount AS NVarChar(20)), N'NULL') + N']: ' + IsNull(@Comment, N'');
                PRINT (@PrintMessage);
            END
            IF @DEBUG & 0x04 <> 0 BEGIN
                SELECT
                    [DebugInfo.SubPoint]  = QuoteName(@ObjectSchema) + N'.' + QuoteName(@ObjectName),
                    [Comment]             = @Comment,
                    ----
                    [Values1.Name]      = V1.[Name],
                    [Values1.Value]     = V1.[Value],
                    [Values2.Name]      = V2.[Name],
                    [Values2.Value]     = V2.[Value],
                    [Values3.Name]      = V3.[Name],
                    [Values3.Value]     = V3.[Value],
                    [Values4.Name]      = V4.[Name],
                    [Values4.Value]     = V4.[Value]
                FROM (VALUES (NULL)) R([Null])
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 1) V1
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 2) V2
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 3) V3
                OUTER APPLY (SELECT TOP (1) * FROM @Values WHERE [Index] = 4) V4;
            END;
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        RETURN (0);
    ----------------------------------------------------------------------------
    END TRY
    BEGIN CATCH
    ----------------------------------------------------------------------------
        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID;
    ----------------------------------------------------------------------------
    END CATCH;
    ----------------------------------------------------------------------------

GO

/****** Object:  StoredProcedure [Debug].[Executions@Load]    Script Date: 04/11/2018 16:31:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--==================================================================================================
-- <Назначение>:        Процедура загрузки логов из файлов в БД;
-- <Версия>:            v4.0;
-- <Автор>:             Gagarkin;
-- <Дата создания>:     18.02.2018;
-- <Комментарий>:       Использование Extended Events;
---=================================================================================================
CREATE PROCEDURE [Debug].[Executions@Load]
    @Event_Id                       TinyInt         = 82,
    @Path                           NVarChar(1000)  = N'D:\DB_DATA\DEBUG',
    @FilesMask                      NVarChar(200)   = N'*.xel'
---
    WITH EXECUTE AS OWNER
---
AS
    SET NOCOUNT ON;

    DECLARE
        @DebugDuration              Numeric(18,3),
        @DebugDateTime              DateTime,
        @DebugMessage               NVarChar(Max);

    DECLARE
        @LPath                      NVarChar(1000),
        @LFile_Id                   BigInt,
        @LInitialFileName           NVarChar(1000),
        @LInitialOffset             BigInt,
        
        @RowIndex                   BigInt,

        @EventInfo                  NVarChar(128),
        @EventData                  NVarChar(Max),
        
        @CurrFileName               NVarChar(1000),
        @CurrFileOffset             BigInt,
        @CurrTime                   DateTime2(3),
        @PrevFileName               NVarChar(1000),
        @PrevFileOffset             BigInt,
        @PrevTime                   DateTime2(3),
        
        @InfoKind                   VarChar(50),
        @InfoId                     BigInt,
        @InfoEType                  VarChar(50),
        @InfoEIndex                 Int,
        @InfoPrmEvents              SmallInt,
        @InfoIsLast                 Bit,

        @LSeekId                    BigInt,
        @Parent_Id                  BigInt,
        @StmtIndex                  Int,
        
        @DataDateTime               DateTime2(3),
        @DataTranCount              SmallInt,

        @DataSpId                   Int,
        @DataConnectionGUId         UniqueIdentifier,
        @DataDatabase               SysName,
        @DataObjectSchema           SysName,
        @DataObjectName             SysName,
        @DataObject_Id              Int,
        @DataNestLevel              Int,
        @DataLoginName              NVarChar(256),
        @DataUserName               NVarChar(256),
        @DataHostName               NVarChar(256),

        @DataDuration               Int,
        @DataRows                   Int,
        @DataComment                NVarChar(Max),

        @DataReturn                 Int,
        @DataError                  NVarChar(Max),

        @ParamsJson                 NVarChar(Max),
        
        @MaxRowsInBuffer            Int             = 100000,
        @RowsInBuffer               Int;

    CREATE TABLE #Buffer
    (
        [Row:Index]         BigInt          NOT NULL     IDENTITY(1,1),
        [EventData]         Xml                 NULL,
        [FileName]          NVarChar(100)   NOT NULL,
        [FileOffset]        BigInt          NOT NULL,
        PRIMARY KEY CLUSTERED ([Row:Index])
    );

    ----------------------------------------------------------------------------
    BEGIN TRY
    ----------------------------------------------------------------------------
        SET @DebugDateTime = GetDate();

        IF @@TranCount > 0
            RaisError ('Данная процедар не может быть запущена внутри транзакции!', 16, 2);

        -- Проверка параметров
        IF @Event_Id IS NULL
            RaisError ('Abstract Error: (1) Не задан @Event_Id!', 16, 2);

        IF @Path IS NULL
            RaisError ('Abstract Error: (2) Не задан @Path!', 16, 2);

        IF @FilesMask IS NULL
            RaisError ('Abstract Error: (3) Не задан @FilesMask!', 16, 2);

        SET @LPath  = Replace(@Path + '\' + @FilesMask, '\\', '\');

        ------------------------------------------------------------------------
        IF  NOT EXISTS (SELECT TOP (1) 1 FROM [Debug].[XE:Files:Info]) BEGIN
        ------------------------------------------------------------------------
            -- Первый запуск
            INSERT INTO #Buffer
            SELECT TOP (@MaxRowsInBuffer)
                [event_data],
                [file_name],
                [file_offset]
            FROM [sys].[fn_xe_file_target_read_file](@LPath, Default, NULL, NULL);

            SET @RowsInBuffer   = @@RowCount;
        ------------------------------------------------------------------------
        END ELSE BEGIN
        ------------------------------------------------------------------------
            -- Стандартный запуск
            SELECT TOP (1)
                @LFile_Id               = FI.[Id],
                @LInitialFileName       = FI.[FileName],
                @LInitialOffset         = FI.[LastFileOffset]
            FROM [Debug].[XE:Files:Info]    AS FI
            ORDER BY
                FI.[Id] DESC;

            --SELECT
            --    [@LFile_Id]             = @LFile_Id,
            --    [@LInitialFileName]     = @LInitialFileName,
            --    [@LInitialOffset]       = @LInitialOffset

            INSERT INTO #Buffer
            SELECT TOP (@MaxRowsInBuffer)
                [event_data],
                [file_name],
                [file_offset]
            FROM [sys].[fn_xe_file_target_read_file](@LPath, Default, @LInitialFileName, @LInitialOffset);

            SET @RowsInBuffer   = @@RowCount;
        ------------------------------------------------------------------------
        END;
        ------------------------------------------------------------------------

        -- <DEBUG>
        SET @DebugDuration  = DateDiff(MilliSecond, @DebugDateTime, GetDate()) / 1000.0;
        SET @DebugDateTime  = GetDate();
        SET @DebugMessage   = Convert(NVarChar(50), @DebugDateTime, 121) + ' ' + Convert(NVarChar(50), @DebugDateTime, 114) + N': '
                            + N'[' + Right('       ' + Convert(NVarChar(50), @DebugDuration), 10) + N']: '
                            + N'Загрузка записей из файлов';
        EXEC [SQL].[Print] @DebugMessage;
        -- </DEBUG>

        SELECT [Loaded records from disk: @@RowCount] = @RowsInBuffer;

        IF @RowsInBuffer = @MaxRowsInBuffer BEGIN
            SELECT TOP (1)
                @CurrFileName   = [FileName],
                @CurrFileOffset = [FileOffset]
            FROM #Buffer AS B
            ORDER BY
                B.[Row:Index] DESC;

            SELECT [@RowsInBuffer] = ' = @MaxRowsInBuffer', [@CurrFileName] = @CurrFileName, [@CurrFileOffset] = @CurrFileOffset;

            SELECT TOP (1)
                @RowIndex       = B.[Row:Index]
            FROM #Buffer AS B
            WHERE  (B.[FileName] <> @CurrFileName)
                OR (B.[FileName] = @CurrFileName AND B.[FileOffset] < @CurrFileOffset)
            ORDER BY
                B.[Row:Index] DESC;

            SELECT [@RowIndex Delete After] = @RowIndex;

            DELETE FROM B
            FROM #Buffer AS B
            WHERE B.[Row:Index] > @RowIndex;
        END;
        -- SELECT * FROM #Buffer

        ------------------------------------------------------------------------
        BEGIN TRAN TRAN_Debug_Load;
        ------------------------------------------------------------------------

            SET @RowIndex       = 0;
            SET @PrevFileName   = @LInitialFileName;
            SET @PrevFileOffset = @LInitialOffset;
            SET @PrevTime       = NULL;

            --------------------------------------------------------------------
            WHILE 1 = 1 BEGIN
            --------------------------------------------------------------------
                SELECT TOP (1)
                    @RowIndex       = [Row:Index],
                    @CurrFileName   = B.[FileName],
                    @CurrFileOffset = B.[FileOffset],
                    @CurrTime       = ED.[TimeStamp],
                    @EventInfo      = ED.[Info],
                    @EventData      = Cast(Convert(VarBinary(8000), ED.[Data], 1) AS NVarChar(Max))
                FROM #Buffer                                                    AS B
                CROSS APPLY B.[EventData].nodes('event[@name="user_event"][1]') AS EData(Record)
                CROSS APPLY
                (
                    SELECT
                        [TimeStamp] = EData.Record.value('@timestamp[1]', 'DateTime2(3)'),
                        [Info]      = EData.Record.value('data[@name="user_info"][1]/value[1]', 'NVarChar(128)'),
                        [Data]      = Cast('0x' AS VarChar(Max)) + EData.Record.value('data[@name="user_data"][1]/value[1]', 'VarChar(Max)')
                ) ED
                WHERE B.[Row:Index] > @RowIndex;

                IF @@RowCount <= 0
                    BREAK;

                -- Чистим локальные параметра от предыдущей итерации
                SET @InfoId         = NULL;
                SET @InfoKind       = NULL;
                SET @InfoEType      = NULL;
                SET @InfoEIndex     = NULL;
                SET @InfoPrmEvents  = NULL;
                SET @InfoIsLast     = NULL;
                SET @StmtIndex      = NULL;
                SET @ParamsJson     = NULL;

                -- Пишем памятку о прочитанных файлах в [Debug].[XE:Files:Info]
                IF (@PrevFileName IS NULL) OR (@PrevFileName <> @CurrFileName) BEGIN
                    IF (@LFile_Id IS NOT NULL) BEGIN
                        UPDATE [Debug].[XE:Files:Info] SET
                            [LastFileOffset]    = @PrevFileOffset,
                            [LastDateTime]      = @PrevTime,
                            [ProccededDateTime] = GetDate()
                        WHERE   [Id] = @LFile_Id
                            AND [System].[Raise Error]
                                (
                                    @@ProcId,
                                    CASE
                                        WHEN @PrevFileName IS NOT NULL AND [FileName] <> @PrevFileName
                                            THEN    N'(11) Ошибка обработки Debug-логов! У записи [Debug].[XE:Files:Info].[Id] = ' + IsNull(Cast(@LFile_Id AS NVarChar(50)), N'NULL')
                                                +   N' не совпадаем название файла [FileName] = ' + IsNull([FileName], N'NULL') + N' со значением в переменной @PrevFileName = ' + IsNull(@PrevFileName, N'NULL')
                                    END
                                ) IS NULL
                    END;

                    COMMIT TRAN TRAN_Debug_Load;

                    -- <DEBUG>
                    SET @DebugDuration  = DateDiff(MilliSecond, @DebugDateTime, GetDate()) / 1000.0;
                    SET @DebugDateTime  = GetDate();
                    SET @DebugMessage   = Convert(NVarChar(50), @DebugDateTime, 121) + ' ' + Convert(NVarChar(50), @DebugDateTime, 114) + N': '
                                        + N'[' + Right('       ' + Convert(NVarChar(50), @DebugDuration), 10) + N']: '
                                        + N'Обработан файл. Id = ' + Cast(@LFile_Id AS NVarChar(50)) + '; @RowIndex = ' + Convert(NVarChar(50), @RowIndex);
                    EXEC [SQL].[Print] @DebugMessage;
                    -- </DEBUG>
                    SELECT [File finished! Id:] = @LFile_Id, [ProccededDateTime] = GetDate(), [@PrevFileOffset] = @PrevFileOffset, [@PrevTime]  = @PrevTime

                    BEGIN TRAN TRAN_Debug_Load;

                    INSERT INTO [Debug].[XE:Files:Info]
                        ([FileName], [LastFileOffset], [StartDateTime], [LastDateTime], [ProccededDateTime])
                    VALUES
                        (@CurrFileName, NULL, @CurrTime, NULL, NULL);

                    SET @LFile_Id   = Scope_Identity();
                END;

                SET @PrevFileName   = @CurrFileName;
                SET @PrevFileOffset = @CurrFileOffset;
                SET @PrevTime       = @CurrTime;

                IF @EventInfo IS NULL
                    RaisError ('Abstract Error: @EventInfo IS NULL; @CurrFileName = %s, @CurrFileOffset = %I64d, @EventInfo = %s', 16, 2, @CurrFileName, @CurrFileOffset, @EventInfo);

                IF IsJson(@EventInfo) = 0 BEGIN
                    IF @@TranCount > 0
                        ROLLBACK;
                    CREATE TABLE ##EventInfo ([EventInfo] NVarChar(Max) NULL)
                    INSERT INTO ##EventInfo VALUES (@EventInfo);
                    PRINT 'SELECT * FROM ##EventInfo';
                    RaisError ('Abstract Error: @EventInfo IS NOT JSON; @CurrFileName = %s, @CurrFileOffset = %I64d, @EventInfo = %s', 16, 2, @CurrFileName, @CurrFileOffset, @EventInfo);
                END;

                -- Читаем параметры @EventInfo
                SELECT TOP (1)
                    @InfoKind       = I.[Kind],
                    @InfoId         = I.[Id],
                    @InfoEType      = I.[EType],
                    @InfoEIndex     = I.[EIndex],
                    @InfoPrmEvents  = I.[PrmEvents],
                    @InfoIsLast     = I.[IsLast]
                FROM OPENJSON(@EventInfo)
                WITH
                (
                    [Kind]      VarChar(100)    '$."Kind"',
                    [Id]        BigInt          '$."Id"',
                    [EType]     VarChar(100)    '$."EType"',
                    [EIndex]    Int             '$."EIndex"',
                    [PrmEvents] Int             '$."PrmEvents"',
                    [IsLast]    Bit             '$."IsLast"'
                ) I;

                IF @InfoId IS NULL
                    RaisError ('Abstract Error: (12) В событии ошибочный идентификатор записи!', 16, 2);

                IF @InfoId IS NULL
                    RaisError ('Abstract Error: (13) В событии ошибочный идентификатор записи!', 16, 2);

                ----------------------------------------------------------------
                IF (@InfoKind = 'Start') AND (@InfoEType = 'Info') BEGIN
                ----------------------------------------------------------------
                    IF IsJson(@EventData) = 0 BEGIN
                        IF @@TranCount > 0
                            ROLLBACK;
                        CREATE TABLE ##EventDataStart ([EventData] NVarChar(Max) NULL)
                        INSERT INTO ##EventDataStart VALUES (@EventData);
                        PRINT 'SELECT * FROM ##EventDataStart';
                        RaisError ('Abstract Error: @EventData IS NOT JSON; @InfoKind = %s, @InfoEType = %s, @EventData = %s', 16, 2, @InfoKind, @InfoEType, @EventData);
                    END;

                    -- Читаем параметры из @@EventData
                    SELECT
                        @DataSpId                   = ED.[SpId],
                        @DataDatabase               = ED.[Database],
                        @DataObjectSchema           = ED.[ObjectSchema],
                        @DataObjectName             = ED.[ObjectName],
                        @DataObject_Id              = ED.[Object_Id],
                        @DataDateTime               = ED.[DateTime],
                        @DataNestLevel              = ED.[NestLevel],
                        @DataLoginName              = ED.[LoginName],
                        @DataUserName               = ED.[UserName],
                        @DataHostName               = ED.[HostName],
                        @DataTranCount              = ED.[TranCount],
                        @DataConnectionGUId         = ED.[ConnectionGUId]
                    FROM OPENJSON (@EventData)
                    WITH
                    (
                        [SpId]              Int                 '$."SpId"',
                        [Database]          SysName             '$."Database"',
                        [ObjectSchema]      SysName             '$."ObjectSchema"',
                        [ObjectName]        SysName             '$."ObjectName"',
                        [Object_Id]         Int                 '$."Object_Id"',
                        [DateTime]          DateTime2           '$."DateTime"',
                        [NestLevel]         SmallInt            '$."NestLevel"',
                        [LoginName]         SysName             '$."LoginName"',
                        [UserName]          SysName             '$."UserName"',
                        [HostName]          SysName             '$."HostName"',
                        [TranCount]         SmallInt            '$."TranCount"',
                        [ConnectionGUId]    UniqueIdentifier    '$."ConnectionGUId"'
                    ) ED;

                    SET @DataDuration = CASE WHEN @DataDuration < 0 THEN 0 ELSE @DataDuration END;

                    -- Определяем @Parent_Id
                    SET @Parent_Id  = NULL;

                    IF @DataNestLevel > 1 BEGIN
                        SELECT TOP (1)
                            @Parent_Id  =   CASE
                                                WHEN
                                                        (   (@DataConnectionGUId IS NULL AND S.[ConnectionGUId] IS NULL)
                                                        OR  (S.[ConnectionGUId]  = @DataConnectionGUId)
                                                        )
                                                    AND NOT EXISTS
                                                        (
                                                            -- Работа процедуры еще не закончилась
                                                            SELECT TOP (1) 1
                                                            FROM [Debug].[Execution:Finish] AS F
                                                            WHERE F.[Id] = S.[Id]
                                                        )
                                                THEN S.[Id]
                                            END
                        FROM [Debug].[Execution:Start]  AS S
                        WHERE   S.[SpId] = @DataSpId
                            AND S.[NestLevel] < @DataNestLevel
                            AND S.[Id] < @InfoId
                        ORDER BY
                            S.[Id] DESC;
                    END;

                    -- Фиксируем Start
                    INSERT INTO [Debug].[Execution:Start]
                    (
                        [Id],
                        [Parent_Id],
                        [Database],
                        [Schema],
                        [Object],
                        [Object_Id],
                        [StartDateTime],
                        [NestLevel],
                        [HostName],
                        [LoginName],
                        [UserName],
                        [SpId],
                        [TranCount],
                        [ConnectionGUId],
                        [PrmSectionsCount]
                    )
                    VALUES
                    (
                        @InfoId,
                        @Parent_Id,
                        @DataDatabase,
                        @DataObjectSchema,
                        @DataObjectName,
                        @DataObject_Id,
                        @DataDateTime,
                        @DataNestLevel,
                        @DataHostName,
                        @DataLoginName,
                        @DataUserName,
                        @DataSpId,
                        @DataTranCount,
                        @DataConnectionGUId,
                        @InfoPrmEvents
                    );
                ----------------------------------------------------------------
                END ELSE IF (@InfoKind = 'Start') AND (@InfoEType = 'PrmSection') BEGIN
                ----------------------------------------------------------------
                    -- Фиксируем PrmSection
                    INSERT INTO [Debug].[Execution:Start:PrmData]
                    (
                        [Id],
                        [Index],
                        [Data]
                    )
                    VALUES
                    (
                        @InfoId,
                        @InfoEIndex,
                        @EventData
                    );

                    IF @InfoIsLast = 1 BEGIN
                        SET @ParamsJson     = NULL;

                        -- Получаем JSON с параметрами вызова
                        SELECT 
                            @ParamsJson     = [Pub].[Concat](PD.[Data], '')
                        FROM
                        (
                            SELECT TOP (10000)
                                [Data]      = Cast(PD.[Data] AS NVarChar(Max))
                            FROM [Debug].[Execution:Start:PrmData]  AS PD
                            WHERE PD.[Id] = @InfoId
                            ORDER BY
                                PD.[Index]
                        ) PD

                        DELETE FROM PD
                        FROM [Debug].[Execution:Start:PrmData]  AS PD
                        WHERE PD.[Id] = @InfoId;

                        IF IsJson(@ParamsJson) = 0 BEGIN
                            IF IsJson(@ParamsJson + N']') = 1
                                SET @ParamsJson = @ParamsJson + N']';

                            IF IsJson(@ParamsJson + N'}') = 1
                                SET @ParamsJson = @ParamsJson + N'}';

                            IF IsJson(@ParamsJson) = 0 BEGIN
                                IF @@TranCount > 0
                                    ROLLBACK;
                                CREATE TABLE ##ParamsJsonStart ([ParamsJson] NVarChar(Max) NULL)
                                INSERT INTO ##ParamsJsonStart VALUES (@ParamsJson);
                                PRINT 'SELECT * FROM ##ParamsJsonStart';
                                RaisError ('Abstract Error: @ParamsJson IS NOT JSON; @ParamsJson = %s', 16, 2, @ParamsJson);
                            END;
                        END;

                        -- Наполняем параметры
                        INSERT INTO [Debug].[Execution:Start:Params]
                        (
                            [Id],
                            [Index],
                            [Name],
                            [Value]
                        )
                        SELECT
                            [Id]            = @InfoId,
                            [Index]         = J.[Index],
                            [Name]          = J.[Name],
                            [Value]         = J.[Value]
                        FROM OPENJSON(@ParamsJson)
                        WITH
                        (
                                [Index]     Int             '$."Index"',
                                [Name]      SysName         '$."Name"',
                                [Value]     NVarChar(Max)   '$."Value"'
                        )   AS J
                    END;
                ----------------------------------------------------------------
                END ELSE IF (@InfoKind = 'Point' OR @InfoKind = 'SubPoint') AND (@InfoEType = 'Info') BEGIN
                ----------------------------------------------------------------
                    IF IsJson(@EventData) = 0 BEGIN
                        IF @@TranCount > 0
                            ROLLBACK;
                        CREATE TABLE ##EventDataPoint ([EventData] NVarChar(Max) NULL)
                        INSERT INTO ##EventDataPoint VALUES (@EventData);
                        PRINT 'SELECT * FROM ##EventDataPoint';
                        RaisError ('Abstract Error: @EventData IS NOT JSON; @InfoKind = %s, @InfoEType = %s, @EventData = %s', 16, 2, @InfoKind, @InfoEType, @EventData);
                    END;

                    -- Читаем параметры из @EventInfo
                    SELECT
                        @DataSpId                   = ED.[SpId],
                        @DataObject_Id              = ED.[Object_Id],
                        @DataDateTime               = ED.[DateTime],
                        @DataDuration               = ED.[Duration],
                        @DataRows                   = ED.[Rows],
                        @DataTranCount              = ED.[TranCount],
                        @DataComment                = ED.[Comment]
                    FROM OPENJSON (@EventData)
                    WITH
                    (
                        [SpId]              Int                 '$."SpId"',
                        [Object_Id]         Int                 '$."Object_Id"',
                        [DateTime]          DateTime2           '$."DateTime"',
                        [Duration]          Int                 '$."Duration"',
                        [Rows]              Int                 '$."Rows"',
                        [TranCount]         SmallInt            '$."TranCount"',
                        [Comment]           NVarChar(Max)       '$."Comment"'
                    ) ED;

                    SET @DataDuration = CASE WHEN @DataDuration < 0 THEN 0 ELSE @DataDuration END;

                    -- Определяем @StmtIndex
                    SET @StmtIndex  = NULL;

                    SELECT TOP (1)
                        @StmtIndex      = ST.[Index]
                    FROM [Debug].[Execution:Stmt]   AS ST
                    WHERE ST.[Exec_Id] = @InfoId
                    ORDER BY
                        ST.[Index] DESC;

                    IF @StmtIndex IS NULL BEGIN
                        
                        SET @LSeekId = @InfoId;

                        WHILE 1 = 1 BEGIN

                            SELECT TOP (1)
                                @LSeekId    = S.[Parent_Id]
                            FROM [Debug].[Execution:Start] AS S
                            WHERE S.[Id] = @LSeekId;

                            IF @@RowCount <= 0
                                BREAK;

                            SELECT TOP (1)
                                @StmtIndex  = ST.[Index]
                            FROM [Debug].[Execution:Start]          AS S
                            INNER JOIN [Debug].[Execution:Start]    AS P    ON P.[Id] = S.[Parent_Id]
                            INNER JOIN [Debug].[Execution:Stmt]     AS ST   ON ST.[Exec_Id] = P.[Id]
                            WHERE S.[Id] = @LSeekId
                            ORDER BY
                                ST.[Index] DESC;

                            IF @StmtIndex IS NOT NULL
                                BREAK;
                        END;
                    END;

                    SET @StmtIndex  = IsNull(@StmtIndex, 0) + 1;

                    -- Фиксируем Point / SubPoint
                    INSERT INTO [Debug].[Execution:Stmt]
                    (
                        [Exec_Id],
                        [Index],
                        [Kind],
                        [DateTime],
                        [Duration],
                        [Rows],
                        [TranCount],
                        [Comment]
                    )
                    VALUES
                    (
                        @InfoId,
                        @StmtIndex,
                        CASE WHEN @InfoKind = 'Point' THEN 'P' ELSE 'p' END,
                        @DataDateTime,
                        @DataDuration,
                        @DataRows,
                        @DataTranCount,
                        @DataComment
                    );
                ----------------------------------------------------------------
                END ELSE IF (@InfoKind = 'Point' OR @InfoKind = 'SubPoint') AND (@InfoEType = 'PrmSection') BEGIN
                ----------------------------------------------------------------
                    -- Определяем @StmtIndex
                    SET @StmtIndex  = NULL;

                    SELECT TOP (1)
                        @StmtIndex      = ST.[Index]
                    FROM [Debug].[Execution:Stmt]   AS ST
                    WHERE ST.[Exec_Id] = @InfoId
                    ORDER BY
                        ST.[Index] DESC;

                    IF @StmtIndex IS NULL
                        RaisError ('Abstract Error: (14) Не удалось определить @StmtIndex для сохранения в [Debug].[Execution:Stmt:PrmData]!', 16, 2);

                    -- Фиксируем PrmSection
                    INSERT INTO [Debug].[Execution:Stmt:PrmData]
                    (
                        [Exec_Id],
                        [Stmt_Index],
                        [Index],
                        [Data]
                    )
                    VALUES
                    (
                        @InfoId,
                        @StmtIndex,
                        @InfoEIndex,
                        @EventData
                    );

                    IF @InfoIsLast = 1 BEGIN
                        -- Получаем JSON с параметрами вызова
                        SET @ParamsJson     = NULL;

                        SELECT 
                            @ParamsJson     = [Pub].[Concat](PD.[Data], '')
                        FROM
                        (
                            SELECT TOP (10000)
                                [Data]      = Cast(PD.[Data] AS NVarChar(Max))
                            FROM [Debug].[Execution:Stmt:PrmData]  AS PD
                            WHERE   PD.[Exec_Id] = @InfoId
                                AND PD.[Stmt_Index] = @StmtIndex
                            ORDER BY
                                PD.[Index]
                        ) PD

                        DELETE FROM PD
                        FROM [Debug].[Execution:Stmt:PrmData]  AS PD
                        WHERE   PD.[Exec_Id] = @InfoId
                            AND PD.[Stmt_Index] = @StmtIndex;

                        IF IsJson(@ParamsJson) = 0 BEGIN
                            IF IsJson(@ParamsJson + N']') = 1 
                                SET @ParamsJson = @ParamsJson + N']';

                            IF IsJson(@ParamsJson + N'}') = 1 
                                SET @ParamsJson = @ParamsJson + N'}';

                            IF IsJson(@ParamsJson) = 0 BEGIN
                                IF @@TranCount > 0
                                    ROLLBACK;
                                CREATE TABLE ##ParamsJsonPoint ([ParamsJson] NVarChar(Max) NULL)
                                INSERT INTO ##ParamsJsonPoint VALUES (@ParamsJson);
                                PRINT 'SELECT * FROM ##ParamsJsonPoint';
                                RaisError ('Abstract Error: @ParamsJson IS NOT JSON; @ParamsJson = %s', 16, 2, @ParamsJson);
                            END;
                        END;

                        -- Наполняем параметры
                        INSERT INTO [Debug].[Execution:Stmt:Params]
                        (
                            [Exec_Id],
                            [Stmt_Index],
                            [Index],
                            [Name],
                            [Value]
                        )
                        SELECT
                            [Exec_Id]       = @InfoId,
                            [Stmt_Index]    = @StmtIndex,
                            [Index]         = J.[Index],
                            [Name]          = J.[Name],
                            [Value]         = J.[Value]
                        FROM OPENJSON(@ParamsJson)
                        WITH
                        (
                                [Index]     Int             '$."Index"',
                                [Name]      SysName         '$."Name"',
                                [Value]     NVarChar(Max)   '$."Value"'
                        )   AS J
                    END;
                ----------------------------------------------------------------
                END  ELSE IF (@InfoKind = 'Finish') AND (@InfoEType = 'Info') BEGIN
                ----------------------------------------------------------------
                    IF IsJson(@EventData) = 0 BEGIN
                        IF @@TranCount > 0
                            ROLLBACK;
                        CREATE TABLE ##EventData ([EventData] NVarChar(Max) NULL)
                        INSERT INTO ##EventData VALUES (@EventData);
                        PRINT 'SELECT * FROM ##EventData';
                        RaisError ('Abstract Error: @EventData IS NOT JSON; @InfoKind = %s, @InfoEType = %s, @EventData = %s', 16, 2, @InfoKind, @InfoEType, @EventData);
                    END;

                    -- Читаем параметры из @EventInfo
                    SELECT
                        @DataSpId                   = ED.[SpId],
                        @DataObject_Id              = ED.[Object_Id],
                        @DataDateTime               = ED.[DateTime],
                        @DataDuration               = ED.[Duration],
                        @DataReturn                 = ED.[Return],
                        @DataTranCount              = ED.[TranCount],
                        @DataError                  = ED.[Error]
                    FROM OPENJSON (@EventData)
                    WITH
                    (
                        [SpId]              Int                 '$."SpId"',
                        [Object_Id]         Int                 '$."Object_Id"',
                        [DateTime]          DateTime2           '$."DateTime"',
                        [Duration]          Int                 '$."Duration"',
                        [Return]            Int                 '$."Return"',
                        [TranCount]         SmallInt            '$."TranCount"',
                        [Error]             NVarChar(Max)       '$."Error"'
                    ) ED;


                    SET @DataDuration = CASE WHEN @DataDuration < 0 THEN 0 ELSE @DataDuration END;
                    
                    -- Определяем @StmtIndex
                    SET @StmtIndex  = NULL;

                    SELECT TOP (1)
                        @StmtIndex      = ST.[Index]
                    FROM [Debug].[Execution:Stmt]   AS ST
                    WHERE ST.[Exec_Id] = @InfoId
                    ORDER BY
                        ST.[Index] DESC;

                    IF @StmtIndex IS NULL BEGIN
                        
                        SET @LSeekId = @InfoId;

                        WHILE 1 = 1 BEGIN

                            SELECT TOP (1)
                                @LSeekId    = S.[Parent_Id]
                            FROM [Debug].[Execution:Start] AS S
                            WHERE S.[Id] = @LSeekId;

                            IF @@RowCount <= 0
                                BREAK;

                            SELECT TOP (1)
                                @StmtIndex  = ST.[Index]
                            FROM [Debug].[Execution:Start]          AS S
                            INNER JOIN [Debug].[Execution:Start]    AS P    ON P.[Id] = S.[Parent_Id]
                            INNER JOIN [Debug].[Execution:Stmt]     AS ST   ON ST.[Exec_Id] = P.[Id]
                            WHERE S.[Id] = @LSeekId
                            ORDER BY
                                ST.[Index] DESC;

                            IF @StmtIndex IS NOT NULL
                                BREAK;
                        END;
                    END;
   
                    SET @StmtIndex  = IsNull(@StmtIndex, 0) + 1;

                    -- Фиксируем Finish
                    INSERT INTO [Debug].[Execution:Finish]
                    (
                        [Id],
                        [EndDateTime],
                        [Duration],
                        [Return],
                        [TranCount],
                        [Error]
                    )
                    VALUES
                    (
                        @InfoId,
                        @DataDateTime,
                        @DataDuration,
                        @DataReturn,
                        @DataTranCount,
                        @DataError
                    );
                ----------------------------------------------------------------
                END;
            --------------------------------------------------------------------
            END;
            --------------------------------------------------------------------

            -- Пишем памятку о последней прочитанной части файла в [Debug].[XE:Files:Info]
            IF @LFile_Id IS NOT NULL AND @CurrFileOffset IS NOT NULL BEGIN

                -- <DEBUG>
                SET @DebugDuration  = DateDiff(MilliSecond, @DebugDateTime, GetDate()) / 1000.0;
                SET @DebugDateTime  = GetDate();
                SET @DebugMessage   = Convert(NVarChar(50), @DebugDateTime, 121) + ' ' + Convert(NVarChar(50), @DebugDateTime, 114) + N': '
                                    + N'[' + Right('       ' + Convert(NVarChar(50), @DebugDuration), 10) + N']: '
                                    + N'КОНЕЦ. Обработан файл. Id = ' + Cast(@LFile_Id AS NVarChar(50)) + '; @RowIndex = ' + Convert(NVarChar(50), @RowIndex);
                EXEC [SQL].[Print] @DebugMessage;
                -- </DEBUG>

                UPDATE [Debug].[XE:Files:Info] SET
                    [LastFileOffset]    = @CurrFileOffset,
                    [LastDateTime]      = @CurrTime,
                    [ProccededDateTime] = GetDate()
                WHERE [Id] = @LFile_Id
                AND [System].[Raise Error]
                    (
                        @@ProcId,
                        CASE
                            WHEN @PrevFileName IS NOT NULL AND [FileName] <> @CurrFileName
                                THEN    N'(21) Ошибка обработки Debug-логов! У записи [Debug].[XE:Files:Info].[Id] = ' + IsNull(Cast(@LFile_Id AS NVarChar(50)), N'NULL')
                                    +   N' не совпадаем название файла [FileName] = ' + IsNull([FileName], N'NULL') + N' со значением в переменной @CurrFileName = ' + IsNull(@CurrFileName, N'NULL')
                        END
                    ) IS NULL;
            END;

        ------------------------------------------------------------------------
        COMMIT TRAN TRAN_Debug_Load;
        ------------------------------------------------------------------------
        
        RETURN (0);
    ----------------------------------------------------------------------------
    END TRY
    BEGIN CATCH
    ----------------------------------------------------------------------------
        IF @@TranCount > 0
            ROLLBACK;

        EXEC [System].[ReRaise Error] @ProcedureId = @@PROCID;
    ----------------------------------------------------------------------------
    END CATCH;
    ----------------------------------------------------------------------------

GO


/****** Object:  UserDefinedFunction [Debug].[Date@ToString]    Script Date: 04/11/2018 16:38:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [Debug].[Date@ToString](@DateTime Date)
    RETURNS VarChar(50)
    WITH
        RETURNS NULL ON NULL INPUT
AS
BEGIN
    RETURN Convert(VarChar(50), @DateTime, 121) -- + ' ' + Convert(VarChar(50), @DateTime, 114)
END

GO

