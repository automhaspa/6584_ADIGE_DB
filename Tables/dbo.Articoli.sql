CREATE TABLE [dbo].[Articoli]
(
[Id_Articolo] [numeric] (18, 0) NOT NULL IDENTITY(1, 1),
[Codice] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (120) COLLATE Latin1_General_CI_AS NOT NULL,
[Barcode] [varchar] (50) COLLATE Latin1_General_CI_AS NULL CONSTRAINT [DF_Articoli_Barcode] DEFAULT ('?'),
[Unita_Misura] [varchar] (3) COLLATE Latin1_General_CI_AS NULL,
[Note] [varchar] (255) COLLATE Latin1_General_CI_AS NULL,
[Qta_Udc] [int] NULL,
[Qta_SottoScorta] [int] NULL,
[Classe] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[Peso] [numeric] (14, 4) NULL,
[Eliminabile] [bit] NOT NULL CONSTRAINT [DF_Articoli_Eliminabile] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Articoli] ADD CONSTRAINT [PK_Articoli] PRIMARY KEY CLUSTERED ([Id_Articolo]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Articoli] ADD CONSTRAINT [Unique_ItemCode] UNIQUE NONCLUSTERED ([Codice]) ON [PRIMARY]
GO
