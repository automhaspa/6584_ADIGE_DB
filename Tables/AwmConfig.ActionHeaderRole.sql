CREATE TABLE [AwmConfig].[ActionHeaderRole]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL,
[ProcedureKey] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Role] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionHeaderRole] ADD CONSTRAINT [PK_ActionHeaderRole] PRIMARY KEY CLUSTERED ([hash], [ProcedureKey], [Role]) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[ActionHeaderRole] ADD CONSTRAINT [FK_ActionHeaderRole_ActionHeader] FOREIGN KEY ([hash], [ProcedureKey]) REFERENCES [AwmConfig].[ActionHeader] ([hash], [ProcedureKey]) ON DELETE CASCADE ON UPDATE CASCADE
GO
