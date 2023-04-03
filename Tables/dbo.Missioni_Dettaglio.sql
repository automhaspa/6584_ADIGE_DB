CREATE TABLE [dbo].[Missioni_Dettaglio]
(
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Id_Lista] [int] NOT NULL,
[Id_Dettaglio] [int] NOT NULL,
[Id_Articolo] [numeric] (18, 0) NOT NULL,
[Lotto] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[Quantita] [numeric] (18, 2) NOT NULL,
[Id_Stato_Articolo] [int] NOT NULL,
[Qta_Orig] [numeric] (18, 2) NOT NULL,
[Id_Gruppo_Lista] [int] NOT NULL,
[Id_UdcDettaglio] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Missioni_Dettaglio] ADD CONSTRAINT [PK_Missioni_Dettaglio] PRIMARY KEY CLUSTERED ([Id_Udc], [Id_Dettaglio], [Lotto]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Missioni_Dettaglio] ADD CONSTRAINT [FK_Missioni_Dettaglio_Articoli] FOREIGN KEY ([Id_Articolo]) REFERENCES [dbo].[Articoli] ([Id_Articolo])
GO
ALTER TABLE [dbo].[Missioni_Dettaglio] ADD CONSTRAINT [FK_Missioni_Dettaglio_Lista_Host_Gruppi] FOREIGN KEY ([Id_Gruppo_Lista]) REFERENCES [dbo].[Lista_Host_Gruppi] ([Id_Gruppo_Lista])
GO
ALTER TABLE [dbo].[Missioni_Dettaglio] ADD CONSTRAINT [FK_Missioni_Dettaglio_Tipo_Stato_Articolo] FOREIGN KEY ([Id_Stato_Articolo]) REFERENCES [dbo].[Tipo_Stato_Articolo] ([Id_Stato_Articolo])
GO
ALTER TABLE [dbo].[Missioni_Dettaglio] ADD CONSTRAINT [FK_Missioni_Dettaglio_Udc_Dettaglio1] FOREIGN KEY ([Id_UdcDettaglio]) REFERENCES [dbo].[Udc_Dettaglio] ([Id_UdcDettaglio])
GO
