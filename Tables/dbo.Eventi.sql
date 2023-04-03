CREATE TABLE [dbo].[Eventi]
(
[Id_Evento] [int] NOT NULL IDENTITY(1, 1),
[Id_Tipo_Evento] [int] NOT NULL,
[Id_Partizione] [int] NOT NULL,
[Id_Tipo_Messaggio] [varchar] (5) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Utente] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Processo] [varchar] (30) COLLATE Latin1_General_CI_AS NULL,
[Xml_Param] [xml] NULL,
[Id_Tipo_Stato_Evento] [int] NOT NULL,
[JSON_PARAM] AS ([dbo].[ParserJSON]([Xml_Param])),
[Date] [datetime] NULL CONSTRAINT [DF_Eventi_Date] DEFAULT (getdate()),
[Id_Evento_Padre] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Eventi] ADD CONSTRAINT [PK_Eventi] PRIMARY KEY CLUSTERED ([Id_Evento]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Eventi] ADD CONSTRAINT [FK_Eventi_Partizioni] FOREIGN KEY ([Id_Partizione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Eventi] ADD CONSTRAINT [FK_Eventi_Tipo_Eventi] FOREIGN KEY ([Id_Tipo_Evento]) REFERENCES [dbo].[Tipo_Eventi] ([Id_Tipo_Evento])
GO
ALTER TABLE [dbo].[Eventi] ADD CONSTRAINT [FK_Eventi_Tipo_Messaggi] FOREIGN KEY ([Id_Tipo_Messaggio]) REFERENCES [dbo].[Tipo_Messaggi] ([Id_Tipo_Messaggio])
GO
ALTER TABLE [dbo].[Eventi] ADD CONSTRAINT [FK_Eventi_Tipo_Stato_Evento] FOREIGN KEY ([Id_Tipo_Stato_Evento]) REFERENCES [dbo].[Tipo_Stato_Evento] ([Id_Tipo_Stato_Evento])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Partizione che ha generato l''evento.', 'SCHEMA', N'dbo', 'TABLE', N'Eventi', 'COLUMN', N'Id_Partizione'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Messaggio che ha generato l''evento.', 'SCHEMA', N'dbo', 'TABLE', N'Eventi', 'COLUMN', N'Id_Tipo_Messaggio'
GO
