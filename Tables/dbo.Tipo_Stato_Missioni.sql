CREATE TABLE [dbo].[Tipo_Stato_Missioni]
(
[Id_Stato_Missione] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Icona] [varchar] (150) COLLATE Latin1_General_CI_AS NOT NULL,
[Selectable] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Stato_Missioni] ADD CONSTRAINT [PK_Tipo_Stato_Missioni] PRIMARY KEY CLUSTERED ([Id_Stato_Missione]) ON [PRIMARY]
GO
