CREATE TABLE [AwmConfig].[ActionParameterWidget]
(
[SourceName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ParameterName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ParameterValue] [nvarchar] (2000) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionParameterWidget] ADD CONSTRAINT [PK_ActionParameterWidget] PRIMARY KEY CLUSTERED ([SourceName], [ParameterName]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionParameterWidget] ADD CONSTRAINT [FK_ActionParameterWidget_ActionParameterSources] FOREIGN KEY ([SourceName]) REFERENCES [AwmConfig].[ActionParameterSources] ([Source]) ON DELETE CASCADE ON UPDATE CASCADE
GO
