CREATE TABLE [dbo].[Tipo_Unita_Misura]
(
[Id_Unita_Misura] [varchar] (2) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (45) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Unita_Misura] ADD CONSTRAINT [PK_Tipo_Unita_Misura] PRIMARY KEY CLUSTERED ([Id_Unita_Misura]) ON [PRIMARY]
GO
