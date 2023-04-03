CREATE TABLE [Custom].[StoricoMerciEntrateModula]
(
[Id_Testata_Ddt_Reale] [int] NOT NULL,
[Id_Riga_Ddt_Reale] [int] NOT NULL,
[Id_Udc_Spostamento] [int] NOT NULL,
[Quantita_Movimentata] [numeric] (10, 2) NULL CONSTRAINT [DF__StoricoMe__Quant__2AAB3E11] DEFAULT ((0))
) ON [PRIMARY]
GO
