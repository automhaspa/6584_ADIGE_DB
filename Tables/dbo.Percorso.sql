CREATE TABLE [dbo].[Percorso]
(
[Id_Percorso] [int] NOT NULL,
[Sequenza_Percorso] [int] NOT NULL,
[Id_Partizione_Sorgente] [int] NULL,
[Id_Partizione_Destinazione] [int] NULL,
[Descrizione] [varchar] (80) COLLATE Latin1_General_CI_AS NULL,
[Stored_Procedure] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Xml_Param] [xml] NULL,
[Id_Tipo_Stato_Percorso] [int] NOT NULL CONSTRAINT [DF_Percorso_Tipo_Stato_Percorso] DEFAULT ((1)),
[Id_Tipo_Messaggio] [varchar] (5) COLLATE Latin1_General_CI_AS NULL,
[Id_Componente_Prenotato] [int] NULL,
[AlarmId] [int] NULL,
[Direzione] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[lastDateCmd] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Percorso] ADD CONSTRAINT [PK_Percorso] PRIMARY KEY CLUSTERED ([Id_Percorso], [Sequenza_Percorso]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Percorso] ADD CONSTRAINT [FK_Percorso_Alarms] FOREIGN KEY ([AlarmId]) REFERENCES [dbo].[Alarms] ([AlarmId])
GO
ALTER TABLE [dbo].[Percorso] ADD CONSTRAINT [FK_Percorso_Missioni] FOREIGN KEY ([Id_Percorso]) REFERENCES [dbo].[Missioni] ([Id_Missione])
GO
ALTER TABLE [dbo].[Percorso] ADD CONSTRAINT [FK_Percorso_Partizioni] FOREIGN KEY ([Id_Partizione_Sorgente]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Percorso] ADD CONSTRAINT [FK_Percorso_Partizioni1] FOREIGN KEY ([Id_Partizione_Destinazione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Percorso] ADD CONSTRAINT [FK_Percorso_Tipo_Messaggi] FOREIGN KEY ([Id_Tipo_Messaggio]) REFERENCES [dbo].[Tipo_Messaggi] ([Id_Tipo_Messaggio])
GO
ALTER TABLE [dbo].[Percorso] ADD CONSTRAINT [FK_Percorso_Tipo_Stato_Percorso] FOREIGN KEY ([Id_Tipo_Stato_Percorso]) REFERENCES [dbo].[Tipo_Stato_Percorso] ([Id_Stato_Percorso])
GO
