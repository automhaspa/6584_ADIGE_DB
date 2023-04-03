CREATE TABLE [Custom].[StoricoPrelievoMancanti]
(
[Id_Testata_Ddt_Reale] [int] NOT NULL,
[Id_Riga_Ddt_Reale] [int] NOT NULL,
[Id_Riga_Lista_Prelievo] [int] NOT NULL,
[Id_Udc] [int] NOT NULL,
[Quantita_Prelevata] [numeric] (10, 2) NOT NULL
) ON [PRIMARY]
GO
