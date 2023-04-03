CREATE TABLE [dbo].[Tipo_Dati]
(
[Id_Tipo_Dato] [varchar] (12) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Dati] ADD CONSTRAINT [PK_Tipo_Dati] PRIMARY KEY CLUSTERED ([Id_Tipo_Dato]) ON [PRIMARY]
GO
