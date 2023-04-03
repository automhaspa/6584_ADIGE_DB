CREATE TABLE [dbo].[Tipo_Causali_Movimenti_Aggiuntiva]
(
[Id_Tipo_Causale] [int] NOT NULL,
[Id_Causale_Aggiuntiva] [varchar] (10) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizone_Causale_Aggiuntiva] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Causali_Movimenti_Aggiuntiva] ADD CONSTRAINT [PK_Tipo_Causali_Movimenti_Aggiuntiva] PRIMARY KEY CLUSTERED ([Id_Tipo_Causale], [Id_Causale_Aggiuntiva]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Causali_Movimenti_Aggiuntiva] ADD CONSTRAINT [FK_Tipo_Causali_Movimenti_Aggiuntiva_Tipo_Causali_Movimenti] FOREIGN KEY ([Id_Tipo_Causale]) REFERENCES [dbo].[Tipo_Causali_Movimenti] ([Id_Tipo_Causale])
GO
