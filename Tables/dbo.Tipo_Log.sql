CREATE TABLE [dbo].[Tipo_Log]
(
[Id_Tipo_Log] [int] NOT NULL,
[Descrizione] [varchar] (30) COLLATE Latin1_General_CI_AS NULL,
[Note] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Log] ADD CONSTRAINT [PK_Tipo_Log] PRIMARY KEY CLUSTERED ([Id_Tipo_Log]) ON [PRIMARY]
GO
