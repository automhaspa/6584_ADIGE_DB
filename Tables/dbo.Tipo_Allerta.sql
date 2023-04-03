CREATE TABLE [dbo].[Tipo_Allerta]
(
[Id_Tipo_Allerta] [int] NOT NULL,
[Descrizione] [varchar] (30) COLLATE Latin1_General_CI_AS NULL,
[Note] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Allerta] ADD CONSTRAINT [PK_Tipo_Allerta] PRIMARY KEY CLUSTERED ([Id_Tipo_Allerta]) ON [PRIMARY]
GO
