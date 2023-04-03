CREATE TABLE [dbo].[Tipo_Stati_Lista]
(
[Id_Stato_Lista] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Icona] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Stati_Lista] ADD CONSTRAINT [PK_Tipo_Stati_Lista] PRIMARY KEY CLUSTERED ([Id_Stato_Lista]) ON [PRIMARY]
GO
