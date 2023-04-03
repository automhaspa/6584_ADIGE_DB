CREATE TABLE [dbo].[Tipo_Stato_Percorso]
(
[Id_Stato_Percorso] [int] NOT NULL IDENTITY(1, 1),
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Icona] [varchar] (150) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Stato_Percorso] ADD CONSTRAINT [PK_Tipo_Stato_Percorso] PRIMARY KEY CLUSTERED ([Id_Stato_Percorso]) ON [PRIMARY]
GO
