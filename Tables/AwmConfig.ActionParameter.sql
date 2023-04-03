CREATE TABLE [AwmConfig].[ActionParameter]
(
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[ProcedureKey] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ParameterName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ParameterSource] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[ParameterValue] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[DisplayOrder] [int] NULL,
[directValidated] [bit] NULL,
[resourceName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[validationModule] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[out] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionParameter] ADD CONSTRAINT [PK_ActionParameter] PRIMARY KEY CLUSTERED ([hash], [ProcedureKey], [ParameterName]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionParameter] ADD CONSTRAINT [FK_ActionParameter_001] FOREIGN KEY ([ParameterSource]) REFERENCES [AwmConfig].[ActionParameterSources] ([Source]) ON DELETE CASCADE ON UPDATE CASCADE
GO
ALTER TABLE [AwmConfig].[ActionParameter] ADD CONSTRAINT [FK_ActionParameter_ActionHeader] FOREIGN KEY ([hash], [ProcedureKey]) REFERENCES [AwmConfig].[ActionHeader] ([hash], [ProcedureKey]) ON DELETE CASCADE ON UPDATE CASCADE
GO
