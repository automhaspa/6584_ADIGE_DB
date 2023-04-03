CREATE TABLE [dbo].[Tipo_Orientamento_Udc]
(
[Id_Tipo_Orientamento_Cassetto] [nchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Orientamento_Udc] ADD CONSTRAINT [PK_Tipo_Orientamento_Cassetto] PRIMARY KEY CLUSTERED ([Id_Tipo_Orientamento_Cassetto]) ON [PRIMARY]
GO
