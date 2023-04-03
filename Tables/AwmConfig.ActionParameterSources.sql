CREATE TABLE [AwmConfig].[ActionParameterSources]
(
[Source] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[WidgetName] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionParameterSources] ADD CONSTRAINT [PK_ActionParameterType] PRIMARY KEY CLUSTERED ([Source]) ON [PRIMARY]
GO
