CREATE TABLE [dbo].[Tipo_AssAnag]
(
[Id_Tipo_Associato] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione_Tipo] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_AssAnag] ADD CONSTRAINT [PK_Tipi_AssAnag] PRIMARY KEY CLUSTERED ([Id_Tipo_Associato]) ON [PRIMARY]
GO
