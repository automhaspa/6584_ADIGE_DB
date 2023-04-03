CREATE TABLE [l3integration].[Quality_Changes]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[TimeStamp] [datetime] NOT NULL,
[Id_Tipo_Stato_Messaggio] [int] NOT NULL,
[Data_UltimoAggiornamento] [datetime] NULL,
[CONTROL_LOT] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Articolo] [int] NOT NULL,
[QUANTITY] [numeric] (10, 3) NOT NULL,
[STAT_QUAL_OLD] [varchar] (4) COLLATE Latin1_General_CI_AS NOT NULL,
[STAT_QUAL_NEW] [varchar] (4) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [l3integration].[Quality_Changes] ADD CONSTRAINT [PK__Quality___3214EC270FBCB2B0] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
