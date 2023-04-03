CREATE TABLE [dbo].[Movimenti]
(
[Id_Movimento] [int] NOT NULL IDENTITY(1, 1),
[Data_Movimento] [datetime] NOT NULL,
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Codice_Udc] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Id_Articolo] [numeric] (18, 0) NOT NULL,
[Codice_Articolo] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Lotto] [varchar] (20) COLLATE Latin1_General_CI_AS NOT NULL,
[Unita_Misura] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Quantita] [numeric] (10, 2) NULL,
[Id_Utente] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Causale_Movimenti] [int] NOT NULL,
[Id_Partizione] [int] NULL,
[Id_Testata_Lista_Prelievo] [int] NULL,
[Id_Riga_Lista_Prelievo] [int] NULL,
[Id_Testata_Ddt_Reale] [int] NULL,
[Id_Riga_Ddt_Reale] [int] NULL,
[Id_Causale_L3] [varchar] (3) COLLATE Latin1_General_CI_AS NULL,
[Codice_Lista] [varchar] (30) COLLATE Latin1_General_CI_AS NULL,
[Codice_Riga] [varchar] (10) COLLATE Latin1_General_CI_AS NULL,
[Data_Lotto] [date] NULL,
[Data_Scadenza] [date] NULL,
[Annotazione] [varchar] (max) COLLATE Latin1_General_CI_AS NULL,
[CODICE_ORDINE] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[CAUSALE] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[PROD_ORDER_LOTTO] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[DESTINAZIONE_DDT] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[CONSEGNA_RAGSOC] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Movimenti] ADD CONSTRAINT [PK_Movimenti] PRIMARY KEY CLUSTERED ([Id_Movimento]) ON [PRIMARY]
GO
