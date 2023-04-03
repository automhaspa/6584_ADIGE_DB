CREATE TABLE [Custom].[Magazzini]
(
[Id_Magazzino] [varchar] (5) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Magazzini] ADD CONSTRAINT [PK__Magazzino] PRIMARY KEY CLUSTERED ([Id_Magazzino]) ON [PRIMARY]
GO
