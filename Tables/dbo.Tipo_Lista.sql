CREATE TABLE [dbo].[Tipo_Lista]
(
[Id_Tipo_Lista] [varchar] (2) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Lista] ADD CONSTRAINT [PK_Tipo_Lista] PRIMARY KEY CLUSTERED ([Id_Tipo_Lista]) ON [PRIMARY]
GO
