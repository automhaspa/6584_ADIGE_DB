CREATE TABLE [Custom].[Tipo_Magazzino]
(
[ID_TIPO_MAGAZZINO] [varchar] (2) COLLATE Latin1_General_CI_AS NOT NULL,
[DESCRIZIONE] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Tipo_Magazzino] ADD CONSTRAINT [PK__Tipo_Mag__D7B9D13FC7217F55] PRIMARY KEY CLUSTERED ([ID_TIPO_MAGAZZINO]) ON [PRIMARY]
GO
