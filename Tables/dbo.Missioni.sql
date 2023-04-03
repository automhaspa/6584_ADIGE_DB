CREATE TABLE [dbo].[Missioni]
(
[Id_Missione] [int] NOT NULL IDENTITY(1, 1),
[Id_Partizione_Sorgente] [int] NOT NULL,
[Id_Partizione_Destinazione] [int] NOT NULL,
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Id_Stato_Missione] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Tipo_Missione] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[Priorita] [int] NULL,
[Id_Raggruppa_Udc] [int] NULL,
[Id_Gruppo_Lista] [int] NULL,
[Data_Creazione] [datetime] NULL CONSTRAINT [DF_Missioni_Data_Creazione] DEFAULT (getdate()),
[Data_Ultima_Modifica] [datetime] NULL,
[Xml_Param] [xml] NULL,
[HANDLINGINFO] [int] NULL,
[QuotaDeposito] [int] NULL,
[QUOTADEPOSITOX] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Missioni] ADD CONSTRAINT [PK_Missioni] PRIMARY KEY CLUSTERED ([Id_Missione]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [Id_Partizione_Destinazione] ON [dbo].[Missioni] ([Id_Partizione_Destinazione]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [Id_Partizione_Sorgente] ON [dbo].[Missioni] ([Id_Partizione_Sorgente]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [Id_Stato_Missione] ON [dbo].[Missioni] ([Id_Stato_Missione]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [Id_Tipo_Missione] ON [dbo].[Missioni] ([Id_Tipo_Missione]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [Id_Udc] ON [dbo].[Missioni] ([Id_Udc]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Missioni] ADD CONSTRAINT [FK_Missioni_Partizioni] FOREIGN KEY ([Id_Partizione_Sorgente]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Missioni] ADD CONSTRAINT [FK_Missioni_Partizioni1] FOREIGN KEY ([Id_Partizione_Destinazione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Missioni] ADD CONSTRAINT [FK_Missioni_Tipo_Missioni] FOREIGN KEY ([Id_Tipo_Missione]) REFERENCES [dbo].[Tipo_Missioni] ([Id_Tipo_Missione])
GO
ALTER TABLE [dbo].[Missioni] ADD CONSTRAINT [FK_Missioni_Tipo_Priorita] FOREIGN KEY ([Priorita]) REFERENCES [dbo].[Tipo_Priorita] ([Priorita])
GO
ALTER TABLE [dbo].[Missioni] ADD CONSTRAINT [FK_Missioni_Tipo_Stato_Missioni] FOREIGN KEY ([Id_Stato_Missione]) REFERENCES [dbo].[Tipo_Stato_Missioni] ([Id_Stato_Missione])
GO
ALTER TABLE [dbo].[Missioni] ADD CONSTRAINT [FK_Missioni_Udc_Testata] FOREIGN KEY ([Id_Udc]) REFERENCES [dbo].[Udc_Testata] ([Id_Udc])
GO
