CREATE TABLE [dbo].[Missioni_Picking_Dettaglio]
(
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Id_UdcDettaglio] [int] NOT NULL,
[Id_Testata_Lista] [int] NOT NULL,
[Id_Riga_Lista] [int] NOT NULL,
[Id_Partizione_Destinazione] [int] NULL,
[Id_Articolo] [numeric] (18, 0) NOT NULL,
[Quantita] [numeric] (18, 2) NOT NULL,
[Qta_Prelevata] [numeric] (10, 2) NULL CONSTRAINT [DF_Missioni_Picking_Dettaglio_Qta_Prelevata] DEFAULT ((0)),
[Flag_SvuotaComplet] [bit] NOT NULL CONSTRAINT [DF_Missioni_Picking_Dettaglio_Flag_SvuotaComplet] DEFAULT ((0)),
[Kit_Id] [int] NOT NULL CONSTRAINT [DF_Missioni_Picking_Dettaglio_Kit_Id] DEFAULT ((0)),
[Id_Stato_Missione] [int] NOT NULL,
[FL_MANCANTI] [bit] NULL,
[DataOra_UltimaModifica] [datetime] NULL,
[DataOra_Evasione] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Missioni_Picking_Dettaglio] ADD CONSTRAINT [PK_Missioni_Picking_Dettaglio] PRIMARY KEY CLUSTERED ([Id_Udc], [Id_UdcDettaglio], [Id_Testata_Lista], [Id_Riga_Lista], [Kit_Id]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Missioni_Picking_Dettaglio] ADD CONSTRAINT [FK_Missioni_Picking_Dettaglio_Articoli] FOREIGN KEY ([Id_Articolo]) REFERENCES [dbo].[Articoli] ([Id_Articolo])
GO
ALTER TABLE [dbo].[Missioni_Picking_Dettaglio] ADD CONSTRAINT [fkMissioniPicking_Id_Riga] FOREIGN KEY ([Id_Riga_Lista]) REFERENCES [Custom].[RigheListePrelievo] ([ID])
GO
ALTER TABLE [dbo].[Missioni_Picking_Dettaglio] ADD CONSTRAINT [fkMissioniPicking_Id_Testata] FOREIGN KEY ([Id_Testata_Lista]) REFERENCES [Custom].[TestataListePrelievo] ([ID])
GO
