CREATE SCHEMA [Debug]
GO

GO

CREATE TYPE [Debug].[Params] AS TABLE(
	[Index] [tinyint] NOT NULL,
	[Name] [sysname] COLLATE Cyrillic_General_CI_AS NOT NULL,
	[Value] [nvarchar](max) COLLATE Cyrillic_General_CI_AS NULL,
	PRIMARY KEY CLUSTERED 
(
	[Index] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO


GO

/****** Object:  Synonym [Debug].[Execution:Disabled]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:Disabled] FOR [CIS.Log].[Debug].[Execution:Disabled]
GO

/****** Object:  Synonym [Debug].[Execution:Finish]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:Finish] FOR [CIS.Log].[Debug].[Execution:Finish]
GO

/****** Object:  Synonym [Debug].[Execution:OtherParams]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:OtherParams] FOR [CIS.Log].[Debug].[Execution:OtherParams]
GO

/****** Object:  Synonym [Debug].[Execution:Start]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:Start] FOR [CIS.Log].[Debug].[Execution:Start]
GO

/****** Object:  Synonym [Debug].[Execution:Start:Params]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:Start:Params] FOR [CIS.Log].[Debug].[Execution:Start:Params]
GO

/****** Object:  Synonym [Debug].[Execution:Stmt]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:Stmt] FOR [CIS.Log].[Debug].[Execution:Stmt]
GO

/****** Object:  Synonym [Debug].[Execution:Stmt:Params]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:Stmt:Params] FOR [CIS.Log].[Debug].[Execution:Stmt:Params]
GO

/****** Object:  Synonym [Debug].[Execution:Stmt->Kinds]    Script Date: 11.04.2018 17:06:27 ******/
CREATE SYNONYM [Debug].[Execution:Stmt->Kinds] FOR [CIS.Log].[Debug].[Execution:Stmt->Kinds]
GO

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

/****** Object:  UserDefinedFunction [Debug].[DateTime@ToString]    Script Date: 11.04.2018 17:11:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [Debug].[DateTime@ToString](@DateTime DateTime)
    RETURNS VarChar(50)
    WITH
        RETURNS NULL ON NULL INPUT
AS
BEGIN
    RETURN Convert(VarChar(50), @DateTime, 121) -- + ' ' + Convert(VarChar(50), @DateTime, 114)
END
GO

/****** Object:  UserDefinedFunction [Debug].[DateTime@ToString?IsNull]    Script Date: 11.04.2018 17:11:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [Debug].[DateTime@ToString?IsNull](@DateTime DateTime, @WithQuoteString Bit = 1)
    RETURNS VarChar(50)
AS
BEGIN
    RETURN IsNull('''' + Convert(VarChar(50), @DateTime, 121) + '''', 'NULL')
END
GO

/****** Object:  UserDefinedFunction [Debug].[Exection@Enabled]    Script Date: 11.04.2018 17:11:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [Debug].[Exection@Enabled](@Proc_Id Int)
  RETURNS Bit
AS
BEGIN
  RETURN
  (
    CASE WHEN NOT EXISTS(SELECT TOP (1) 1 FROM [Debug].[Execution:Disabled])
      THEN CAST(1 AS Bit)
      ELSE CAST(0 AS Bit)
    END
  )
END
GO

/****** Object:  UserDefinedFunction [Debug].[Execution@Enabled]    Script Date: 11.04.2018 17:11:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [Debug].[Execution@Enabled](@Proc_Id Int)
  RETURNS Bit
AS
BEGIN
    RETURN
    (
        CASE WHEN NOT EXISTS(SELECT TOP (1) 1 FROM [Debug].[Execution:Disabled])
            THEN CAST(1 AS Bit)
            ELSE CAST(0 AS Bit)
        END
    );
END;
GO

USE [CIS.Middle]
GO

/****** Object:  StoredProcedure [Debug].[Execution@Finish]    Script Date: 11.04.2018 17:13:23 ******/
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

/****** Object:  StoredProcedure [Debug].[Execution@Point]    Script Date: 11.04.2018 17:13:23 ******/
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
            SET @EventParamsDataLen = Len(@EventParamsData) + 1;
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

/****** Object:  StoredProcedure [Debug].[Execution@Read]    Script Date: 11.04.2018 17:13:23 ******/
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

/****** Object:  StoredProcedure [Debug].[Execution@Start]    Script Date: 11.04.2018 17:13:23 ******/
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
            SET @EventParamsDataLen = Len(@EventParamsData) + 1;
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
                                        SubString(@EventParamsData, (@PrmIndex - 1) * 4000, 4000)
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

/****** Object:  StoredProcedure [Debug].[Execution@SubPoint]    Script Date: 11.04.2018 17:13:23 ******/
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

