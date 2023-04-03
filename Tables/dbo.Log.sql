CREATE TABLE [dbo].[Log]
(
[DataOra_Log] [datetime] NOT NULL CONSTRAINT [DF_Log_DataOra_Log] DEFAULT (getdate()),
[Id_Processo] [varchar] (30) COLLATE Latin1_General_CI_AS NOT NULL,
[Origine_Log] [varchar] (25) COLLATE Latin1_General_CI_AS NOT NULL,
[Proprietà_Log] [varchar] (100) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Utente] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Tipo_Log] [int] NULL,
[Id_Tipo_Allerta] [int] NULL,
[Messaggio] [nvarchar] (max) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Log] ADD CONSTRAINT [FK_Log_Tipo_Allerta] FOREIGN KEY ([Id_Tipo_Allerta]) REFERENCES [dbo].[Tipo_Allerta] ([Id_Tipo_Allerta])
GO
ALTER TABLE [dbo].[Log] ADD CONSTRAINT [FK_Log_Tipo_Log] FOREIGN KEY ([Id_Tipo_Log]) REFERENCES [dbo].[Tipo_Log] ([Id_Tipo_Log])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Data e ora della scrittura del log.', 'SCHEMA', N'dbo', 'TABLE', N'Log', 'COLUMN', N'DataOra_Log'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Utente loggato sull''applicazione di generazione del log.', 'SCHEMA', N'dbo', 'TABLE', N'Log', 'COLUMN', N'Id_Utente'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Testo completo del messaggio di log.', 'SCHEMA', N'dbo', 'TABLE', N'Log', 'COLUMN', N'Messaggio'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Descrizione che indica la provenienza del log.', 'SCHEMA', N'dbo', 'TABLE', N'Log', 'COLUMN', N'Origine_Log'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Applicazione proprietaria del log. Nel caso in cui venga generato un lod da una stored procedure lanciata da una applicazione che usa il Web Services.', 'SCHEMA', N'dbo', 'TABLE', N'Log', 'COLUMN', N'Proprietà_Log'
GO
