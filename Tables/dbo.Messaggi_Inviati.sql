CREATE TABLE [dbo].[Messaggi_Inviati]
(
[ID_MESSAGGIO] [int] NOT NULL IDENTITY(1, 1),
[DATA_ORA] [datetime] NOT NULL CONSTRAINT [DF_Messaggi_Inviati_Data_Ora] DEFAULT (getdate()),
[ID_TIPO_MESSAGGIO] [varchar] (5) COLLATE Latin1_General_CI_AS NOT NULL,
[ID_AREA] [int] NOT NULL,
[ID_SOTTOAREA] [int] NULL,
[ID_COMPONENTE] [int] NULL,
[ID_SOTTOCOMPONENTE] [int] NULL,
[ID_PARTIZIONE] [int] NULL,
[MESSAGGIO] [xml] NOT NULL,
[ID_TIPO_STATO_MESSAGGIO] [int] NOT NULL,
[ID_PLC] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Messaggi_Inviati] ADD CONSTRAINT [PK_Messaggi_Inviati] PRIMARY KEY CLUSTERED ([ID_MESSAGGIO]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Messaggi_Inviati] ADD CONSTRAINT [FK_Messaggi_Inviati_Plc] FOREIGN KEY ([ID_PLC]) REFERENCES [dbo].[Plc] ([Id_Plc])
GO
ALTER TABLE [dbo].[Messaggi_Inviati] ADD CONSTRAINT [FK_Messaggi_Inviati_Tipo_Messaggio] FOREIGN KEY ([ID_TIPO_MESSAGGIO]) REFERENCES [dbo].[Tipo_Messaggi] ([Id_Tipo_Messaggio])
GO
ALTER TABLE [dbo].[Messaggi_Inviati] ADD CONSTRAINT [FK_Messaggi_Inviati_Tipo_Stato_Messaggio] FOREIGN KEY ([ID_TIPO_STATO_MESSAGGIO]) REFERENCES [dbo].[Tipo_Stato_Messaggio] ([Id_Tipo_Stato_Messaggio])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Descrive la data di creazione', 'SCHEMA', N'dbo', 'TABLE', N'Messaggi_Inviati', 'COLUMN', N'DATA_ORA'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Nel protocolle è il MSG_ID', 'SCHEMA', N'dbo', 'TABLE', N'Messaggi_Inviati', 'COLUMN', N'ID_TIPO_MESSAGGIO'
GO
