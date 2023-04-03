CREATE TABLE [AwmConfig].[ActionHeaderLogic]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[ProcedureKey] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[jsFunc] [varchar] (500) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionHeaderLogic] ADD CONSTRAINT [PK_ActionHeaderLogic] PRIMARY KEY CLUSTERED ([Id]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_ActionHeaderLogic] ON [AwmConfig].[ActionHeaderLogic] ([hash], [ProcedureKey], [jsFunc]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionHeaderLogic] ADD CONSTRAINT [FK_ActionHeaderLogic_ActionHeader] FOREIGN KEY ([hash], [ProcedureKey]) REFERENCES [AwmConfig].[ActionHeader] ([hash], [ProcedureKey]) ON UPDATE CASCADE
GO
