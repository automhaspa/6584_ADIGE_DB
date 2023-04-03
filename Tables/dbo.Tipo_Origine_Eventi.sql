CREATE TABLE [dbo].[Tipo_Origine_Eventi]
(
[Id_Tipo_Origine_Evento] [int] NOT NULL IDENTITY(1, 1),
[Sigla] [varchar] (3) COLLATE Latin1_General_CI_AS NULL,
[Descrizione] [varchar] (100) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Origine_Eventi] ADD CONSTRAINT [PK_Tipo_Origine_Eventi] PRIMARY KEY CLUSTERED ([Id_Tipo_Origine_Evento]) ON [PRIMARY]
GO
