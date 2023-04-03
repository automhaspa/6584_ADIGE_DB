CREATE TABLE [dbo].[Parametri_Generali]
(
[Id_Parametro] [nchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Valore] [varchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Parametri_Generali] ADD CONSTRAINT [PK_Parametri_Generali] PRIMARY KEY CLUSTERED ([Id_Parametro]) ON [PRIMARY]
GO
