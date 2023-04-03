CREATE TABLE [dbo].[Procedure_Gestione_Messaggi]
(
[ID_TIPO_MESSAGGIO] [varchar] (5) COLLATE Latin1_General_CI_AS NOT NULL,
[PROCEDURA] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Procedure_Gestione_Messaggi] ADD CONSTRAINT [PK_Procedure_Gestione_Messaggi] PRIMARY KEY CLUSTERED ([ID_TIPO_MESSAGGIO]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Procedure_Gestione_Messaggi] ADD CONSTRAINT [FK_Procedure_Gestione_Messaggi_Tipo_Messaggio] FOREIGN KEY ([ID_TIPO_MESSAGGIO]) REFERENCES [dbo].[Tipo_Messaggi] ([Id_Tipo_Messaggio])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Nome del messaggio nel formato esteso.', 'SCHEMA', N'dbo', 'TABLE', N'Procedure_Gestione_Messaggi', 'COLUMN', N'ID_TIPO_MESSAGGIO'
GO
