CREATE TABLE [dbo].[Adiacenze_Esclusione]
(
[Id_Adiacenza] [int] NOT NULL,
[Tipo_Udc_Esclusa] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Adiacenze_Esclusione] ADD CONSTRAINT [PK_Adiacenze_Esclusione] PRIMARY KEY CLUSTERED ([Id_Adiacenza], [Tipo_Udc_Esclusa]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Adiacenze_Esclusione] ADD CONSTRAINT [FK_Adiacenze_Esclusione_Adiacenze] FOREIGN KEY ([Id_Adiacenza]) REFERENCES [dbo].[Adiacenze] ([Id_Adiacenza])
GO
ALTER TABLE [dbo].[Adiacenze_Esclusione] ADD CONSTRAINT [FK_Adiacenze_Esclusione_Tipo_Udc] FOREIGN KEY ([Tipo_Udc_Esclusa]) REFERENCES [dbo].[Tipo_Udc] ([Id_Tipo_Udc])
GO
