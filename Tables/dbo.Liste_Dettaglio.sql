CREATE TABLE [dbo].[Liste_Dettaglio]
(
[Id_Lista] [int] NOT NULL,
[Id_Dettaglio] [int] NOT NULL IDENTITY(1, 1),
[Id_Articolo] [numeric] (18, 0) NULL,
[Id_Stato_Articolo] [int] NOT NULL,
[Qta_Lista] [numeric] (18, 4) NULL CONSTRAINT [DF_Liste_Dettaglio_Qta_Lista] DEFAULT ((0)),
[Id_Udc] [numeric] (18, 0) NULL,
[Id_Tipo_Udc] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[Lotto] [varchar] (20) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Liste_Dettaglio] ADD CONSTRAINT [PK_Liste_Dettaglio] PRIMARY KEY CLUSTERED ([Id_Dettaglio]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Liste_Dettaglio] ADD CONSTRAINT [FK_Liste_Dettaglio_Articoli] FOREIGN KEY ([Id_Articolo]) REFERENCES [dbo].[Articoli] ([Id_Articolo])
GO
ALTER TABLE [dbo].[Liste_Dettaglio] ADD CONSTRAINT [FK_Liste_Dettaglio_Liste_Testata] FOREIGN KEY ([Id_Lista]) REFERENCES [dbo].[Liste_Testata] ([Id_Lista])
GO
ALTER TABLE [dbo].[Liste_Dettaglio] ADD CONSTRAINT [FK_Liste_Dettaglio_Tipo_Stato_Articolo] FOREIGN KEY ([Id_Stato_Articolo]) REFERENCES [dbo].[Tipo_Stato_Articolo] ([Id_Stato_Articolo])
GO
ALTER TABLE [dbo].[Liste_Dettaglio] ADD CONSTRAINT [FK_Liste_Dettaglio_Tipo_Udc] FOREIGN KEY ([Id_Tipo_Udc]) REFERENCES [dbo].[Tipo_Udc] ([Id_Tipo_Udc])
GO
