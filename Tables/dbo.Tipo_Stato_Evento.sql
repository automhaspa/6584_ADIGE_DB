CREATE TABLE [dbo].[Tipo_Stato_Evento]
(
[Id_Tipo_Stato_Evento] [int] NOT NULL,
[Descrizione] [varchar] (20) COLLATE Latin1_General_CI_AS NULL,
[Descrizione_Abbreviata] [varchar] (3) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Stato_Evento] ADD CONSTRAINT [PK_Tipo_Stato_Evento] PRIMARY KEY CLUSTERED ([Id_Tipo_Stato_Evento]) ON [PRIMARY]
GO
