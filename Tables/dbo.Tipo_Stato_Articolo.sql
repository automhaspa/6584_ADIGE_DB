CREATE TABLE [dbo].[Tipo_Stato_Articolo]
(
[Id_Stato_Articolo] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Icona] [varchar] (60) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Stato_Articolo] ADD CONSTRAINT [PK_Tipo_Stato_Articolo] PRIMARY KEY CLUSTERED ([Id_Stato_Articolo]) ON [PRIMARY]
GO
