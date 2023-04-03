CREATE TABLE [dbo].[Tipo_Causali_Movimenti]
(
[Id_Tipo_Causale] [int] NOT NULL IDENTITY(1, 1),
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Selectable] [bit] NULL,
[Icona] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Causali_Movimenti] ADD CONSTRAINT [PK_Tipo_Causali_Movimenti] PRIMARY KEY CLUSTERED ([Id_Tipo_Causale]) ON [PRIMARY]
GO
