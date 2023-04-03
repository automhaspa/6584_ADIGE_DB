CREATE TABLE [dbo].[ApplicationsLog]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[Message] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL,
[MessageTemplate] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL,
[Level] [nvarchar] (128) COLLATE Latin1_General_CI_AS NULL,
[TimeStamp] [datetime] NOT NULL,
[Exception] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL,
[Properties] [xml] NULL,
[ApplicationName] [nvarchar] (1000) COLLATE Latin1_General_CI_AS NULL,
[RequestId] [nvarchar] (200) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicationsLog] ADD CONSTRAINT [PK_ApplicationsLog] PRIMARY KEY CLUSTERED ([Id]) ON [PRIMARY]
GO
