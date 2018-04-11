/****** Object:  UserDefinedTableType [Debug].[Params]    Script Date: 04/11/2018 16:43:27 ******/
CREATE TYPE [Debug].[Params] AS TABLE(
	[Index] [tinyint] NOT NULL,
	[Name] [sysname] NOT NULL,
	[Value] [nvarchar](max) NULL,
	PRIMARY KEY CLUSTERED 
(
	[Index] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

/****** Object:  Sequence [Debug].[Execution:Id]    Script Date: 11.04.2018 16:49:41 ******/
CREATE SEQUENCE [Debug].[Execution:Id] 
 AS [bigint]
 START WITH 10000000
 INCREMENT BY 1
 MINVALUE -9223372036854775808
 MAXVALUE 9223372036854775807
 CACHE 
GO


CREATE EVENT SESSION [DebugLog] ON SERVER ADD EVENT sqlserver.user_event
(
    ACTION(sqlserver.database_id,sqlserver.session_id,sqlserver.session_server_principal_name,sqlserver.username)
    WHERE ([event_id]=(82))
)
ADD TARGET package0.event_file(SET filename=N'D:\MSSQL\DEBUG\debug-log.xel',max_file_size=(128),max_rollover_files=(256))
WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=NO_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO






-------------------------


GO

/****** Object:  Table [Debug].[Execution:Disabled]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Disabled](
	[Object_Id] [int] NOT NULL,
 CONSTRAINT [PK_Debug.Execution:Disabled] PRIMARY KEY CLUSTERED 
(
	[Object_Id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Finish]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Finish](
	[Id] [bigint] NOT NULL,
	[EndDateTime] [datetime2](7) NULL,
	[Duration] [int] NULL,
	[Return] [int] NULL,
	[Error] [nvarchar](1000) NULL,
	[TranCount] [smallint] NOT NULL,
	[Index] [smallint] NULL,
 CONSTRAINT [PK_Debug.Execution:Finish] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:OtherParams]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:OtherParams](
	[Id] [bigint] NOT NULL,
	[Index] [tinyint] NOT NULL,
	[Name] [sysname] NOT NULL,
	[Value] [nvarchar](max) NULL,
 CONSTRAINT [PK_Debug.Execution:OtherParams] PRIMARY KEY CLUSTERED 
(
	[Id] ASC,
	[Index] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Start]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Start](
	[Id] [bigint] NOT NULL,
	[Parent_Id] [bigint] NULL,
	[Database] [sysname] NOT NULL,
	[Schema] [sysname] NOT NULL,
	[Object] [sysname] NOT NULL,
	[Object_Id] [int] NULL,
	[StartDateTime] [datetime2](7) NULL,
	[NestLevel] [smallint] NULL,
	[HostName] [sysname] NULL,
	[LoginName] [sysname] NULL,
	[UserName] [sysname] NULL,
	[SpId] [int] NULL,
	[TranCount] [smallint] NULL,
	[ConnectionGUId] [uniqueidentifier] NULL,
	[PrmSectionsCount] [smallint] NULL,
 CONSTRAINT [PK_Debug.Execution:Start] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Start:Params]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Start:Params](
	[Id] [bigint] NOT NULL,
	[Index] [smallint] NOT NULL,
	[Name] [sysname] NOT NULL,
	[Value] [nvarchar](max) NULL,
 CONSTRAINT [PK_Debug.Execution:Start:Params] PRIMARY KEY CLUSTERED 
(
	[Id] ASC,
	[Index] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Start:PrmData]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Start:PrmData](
	[Id] [bigint] NOT NULL,
	[Index] [int] NOT NULL,
	[Data] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_Debug.Execution:Start:PrmData] PRIMARY KEY CLUSTERED 
(
	[Id] ASC,
	[Index] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Start?v3]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Start?v3](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[Parent_Id] [bigint] NULL,
	[Database] [sysname] NOT NULL,
	[Schema] [sysname] NOT NULL,
	[Object] [sysname] NOT NULL,
	[Object_Id] [int] NOT NULL,
	[StartDateTime] [datetime2](7) NOT NULL,
	[NestLevel] [tinyint] NULL,
	[HostName] [sysname] NULL,
	[LoginName] [sysname] NOT NULL,
	[UserName] [sysname] NOT NULL,
	[SpId] [int] NOT NULL,
	[TranCount] [smallint] NOT NULL,
	[Param1.Name] [sysname] NULL,
	[Param1.Value] [nvarchar](max) NULL,
	[Param2.Name] [sysname] NULL,
	[Param2.Value] [nvarchar](max) NULL,
	[Param3.Name] [sysname] NULL,
	[Param3.Value] [nvarchar](max) NULL,
	[Param4.Name] [sysname] NULL,
	[Param4.Value] [nvarchar](max) NULL,
	[Param5.Name] [sysname] NULL,
	[Param5.Value] [nvarchar](max) NULL,
	[Param6.Name] [sysname] NULL,
	[Param6.Value] [nvarchar](max) NULL,
	[ConnectionGUId] [uniqueidentifier] NULL,
	[PrmSectionsCount] [smallint] NULL,
 CONSTRAINT [PK_Debug.Execution:Start?v3] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Stmt]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [Debug].[Execution:Stmt](
	[Exec_Id] [bigint] NOT NULL,
	[Index] [int] NOT NULL,
	[AfterExec_Id] [bigint] NULL,
	[Kind] [char](1) NOT NULL,
	[DateTime] [datetime2](7) NOT NULL,
	[Duration] [int] NULL,
	[Comment] [nvarchar](1024) NULL,
	[Rows] [int] NULL,
	[Values] [varbinary](max) NULL,
	[TranCount] [smallint] NOT NULL,
	[Value1.Name] [sysname] NULL,
	[Value1.Value] [nvarchar](max) NULL,
	[Value2.Name] [sysname] NULL,
	[Value2.Value] [nvarchar](max) NULL,
	[Value3.Name] [sysname] NULL,
	[Value3.Value] [nvarchar](max) NULL,
	[Value4.Name] [sysname] NULL,
	[Value4.Value] [nvarchar](max) NULL,
	[PrmSectionsCount] [smallint] NULL,
 CONSTRAINT [PK_Debug.Execution:Stmt] PRIMARY KEY CLUSTERED 
(
	[Exec_Id] ASC,
	[Index] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING ON
GO


GO

/****** Object:  Table [Debug].[Execution:Stmt:OtherValues]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Stmt:OtherValues](
	[Id] [bigint] NOT NULL,
	[Stmt_Index] [int] NOT NULL,
	[Index] [tinyint] NOT NULL,
	[Name] [sysname] NOT NULL,
	[Value] [nvarchar](max) NULL,
 CONSTRAINT [PK_Debug.Execution:Stmt:OtherValues] PRIMARY KEY CLUSTERED 
(
	[Id] ASC,
	[Stmt_Index] ASC,
	[Index] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Stmt:Params]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Stmt:Params](
	[Exec_Id] [bigint] NOT NULL,
	[Stmt_Index] [int] NOT NULL,
	[Index] [smallint] NOT NULL,
	[Name] [sysname] NOT NULL,
	[Value] [nvarchar](max) NULL,
 CONSTRAINT [PK_Debug.Execution:Stmt:Params] PRIMARY KEY CLUSTERED 
(
	[Exec_Id] ASC,
	[Stmt_Index] ASC,
	[Index] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Stmt:PrmData]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[Execution:Stmt:PrmData](
	[Exec_Id] [bigint] NOT NULL,
	[Stmt_Index] [int] NOT NULL,
	[Index] [int] NOT NULL,
	[Data] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_Debug.Execution:Stmt:PrmData] PRIMARY KEY CLUSTERED 
(
	[Exec_Id] ASC,
	[Stmt_Index] ASC,
	[Index] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO


GO

/****** Object:  Table [Debug].[Execution:Stmt->Kinds]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [Debug].[Execution:Stmt->Kinds](
	[Kind] [char](1) NOT NULL,
	[Name] [nvarchar](100) NULL,
 CONSTRAINT [PK_Debug.Execution:Stmt->Kinds] PRIMARY KEY CLUSTERED 
(
	[Kind] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING ON
GO


GO

/****** Object:  Table [Debug].[XE:Files:Info]    Script Date: 04/11/2018 16:29:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Debug].[XE:Files:Info](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[FileName] [nvarchar](1024) NOT NULL,
	[LastFileOffset] [int] NULL,
	[StartDateTime] [datetime2](7) NOT NULL,
	[LastDateTime] [datetime2](7) NULL,
	[ProccededDateTime] [datetime2](3) NULL,
	[Deleted] [bit] NOT NULL,
 CONSTRAINT [PK_Debug.XE:Files:Info] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

ALTER TABLE [Debug].[Execution:Finish] ADD  CONSTRAINT [DF_Debug.Execution:Finish#TranCount]  DEFAULT (@@trancount) FOR [TranCount]
GO

ALTER TABLE [Debug].[Execution:Start] ADD  CONSTRAINT [DF_Debug.Execution:Start#StartDateTime]  DEFAULT (getdate()) FOR [StartDateTime]
GO

ALTER TABLE [Debug].[Execution:Start] ADD  CONSTRAINT [DF_Debug.Execution:Start#NestLevel]  DEFAULT (@@nestlevel) FOR [NestLevel]
GO

ALTER TABLE [Debug].[Execution:Start] ADD  CONSTRAINT [DF_Debug.Execution:Start#HostName]  DEFAULT (host_name()) FOR [HostName]
GO

ALTER TABLE [Debug].[Execution:Start] ADD  CONSTRAINT [DF_Debug.Execution:Start#LoginName]  DEFAULT (isnull(nullif(original_login(),''),'SYSTEM')) FOR [LoginName]
GO

ALTER TABLE [Debug].[Execution:Start] ADD  CONSTRAINT [DF_Debug.Execution:Start#UserName]  DEFAULT (user_name()) FOR [UserName]
GO

ALTER TABLE [Debug].[Execution:Start] ADD  CONSTRAINT [DF_Debug.Execution:Start#SpId]  DEFAULT (@@spid) FOR [SpId]
GO

ALTER TABLE [Debug].[Execution:Start] ADD  CONSTRAINT [DF_Debug.Execution:Start#TranCount]  DEFAULT (@@trancount) FOR [TranCount]
GO

ALTER TABLE [Debug].[Execution:Start?v3] ADD  CONSTRAINT [DF_Debug.Execution:Start#StartDateTime?v3]  DEFAULT (getdate()) FOR [StartDateTime]
GO

ALTER TABLE [Debug].[Execution:Start?v3] ADD  CONSTRAINT [DF_Debug.Execution:Start?v3#NestLevel]  DEFAULT (@@nestlevel) FOR [NestLevel]
GO

ALTER TABLE [Debug].[Execution:Start?v3] ADD  CONSTRAINT [DF_Debug.Execution:Start#HostName?v3]  DEFAULT (host_name()) FOR [HostName]
GO

ALTER TABLE [Debug].[Execution:Start?v3] ADD  CONSTRAINT [DF_Debug.Execution:Start#LoginName?v3]  DEFAULT (isnull(nullif(original_login(),''),'SYSTEM')) FOR [LoginName]
GO

ALTER TABLE [Debug].[Execution:Start?v3] ADD  CONSTRAINT [DF_Debug.Execution:Start#UserName?v3]  DEFAULT (user_name()) FOR [UserName]
GO

ALTER TABLE [Debug].[Execution:Start?v3] ADD  CONSTRAINT [DF_Debug.Execution:Start#SpId?v3]  DEFAULT (@@spid) FOR [SpId]
GO

ALTER TABLE [Debug].[Execution:Start?v3] ADD  CONSTRAINT [DF_Debug.Execution:Start#TranCount?v3]  DEFAULT (@@trancount) FOR [TranCount]
GO

ALTER TABLE [Debug].[Execution:Stmt]  WITH CHECK ADD  CONSTRAINT [CK__Execution:__Kind__1E5A75C5] CHECK  (([Kind]='p' OR [Kind]='P' OR [Kind]='E' OR [Kind]='F' OR [Kind]='S'))
GO

ALTER TABLE [Debug].[Execution:Stmt] CHECK CONSTRAINT [CK__Execution:__Kind__1E5A75C5]
GO

ALTER TABLE [Debug].[Execution:Stmt] ADD  CONSTRAINT [DF_Debug.Execution:Stmt#DateTime]  DEFAULT (getdate()) FOR [DateTime]
GO

ALTER TABLE [Debug].[Execution:Stmt] ADD  CONSTRAINT [DF_Debug.Execution:Stmt#TranCount]  DEFAULT (@@trancount) FOR [TranCount]
GO

ALTER TABLE [Debug].[XE:Files:Info] ADD  DEFAULT ((0)) FOR [Deleted]
GO


INSERT INTO [Debug].[Execution:Stmt->Kinds]([Kind], [Name])
VALUES
  ('E', 'Error')
  ,  ('F', 'Finish')
  ,  ('P', 'Point')
  ,  ('S', 'Start')
  ,  ('p', 'SubPoint')

GO
