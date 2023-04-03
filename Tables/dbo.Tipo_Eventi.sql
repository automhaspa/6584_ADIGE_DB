CREATE TABLE [dbo].[Tipo_Eventi]
(
[Id_Tipo_Evento] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Id_Tipo_Gestore_Eventi] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[Azione_Evento] [varchar] (100) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Eventi] ADD CONSTRAINT [PK_Tipo_Eventi] PRIMARY KEY CLUSTERED ([Id_Tipo_Evento]) ON [PRIMARY]
GO
