CREATE TABLE [dbo].[Tipo_Direzione_Messaggi]
(
[Id_Tipo_Direzione_Messaggio] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (30) COLLATE Latin1_General_CI_AS NULL,
[Stored_Procedure_Gestione] [varchar] (30) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Direzione_Messaggi] ADD CONSTRAINT [PK_Id_Tipo_Invii_Messaggioù] PRIMARY KEY CLUSTERED ([Id_Tipo_Direzione_Messaggio]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Identificativo univoco del tipo.', 'SCHEMA', N'dbo', 'TABLE', N'Tipo_Direzione_Messaggi', 'COLUMN', N'Id_Tipo_Direzione_Messaggio'
GO
