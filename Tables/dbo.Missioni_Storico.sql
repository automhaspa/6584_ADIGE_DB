CREATE TABLE [dbo].[Missioni_Storico]
(
[Id_Missione] [int] NOT NULL,
[Id_Udc] [int] NOT NULL,
[Codice_Udc] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Tipo_Missione] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[ID_PARTIZIONE_SORGENTE] [int] NOT NULL,
[Sorgente] [varchar] (14) COLLATE Latin1_General_CI_AS NULL,
[ID_PARTIZIONE_DESTINAZIONE] [int] NOT NULL,
[Destinazione] [varchar] (14) COLLATE Latin1_General_CI_AS NULL,
[QuotaDeposito] [int] NULL,
[Stato_Missione] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[Data] [datetime] NOT NULL CONSTRAINT [DF_Missioni_Storico_Data] DEFAULT (getdate()),
[MOTIVO_RCS] [xml] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Missioni_Storico] ADD CONSTRAINT [FK_Missioni_Storico_Tipo_Missioni] FOREIGN KEY ([Id_Tipo_Missione]) REFERENCES [dbo].[Tipo_Missioni] ([Id_Tipo_Missione])
GO
ALTER TABLE [dbo].[Missioni_Storico] ADD CONSTRAINT [FK_Missioni_Storico_Tipo_Stato_Missioni] FOREIGN KEY ([Stato_Missione]) REFERENCES [dbo].[Tipo_Stato_Missioni] ([Id_Stato_Missione])
GO
