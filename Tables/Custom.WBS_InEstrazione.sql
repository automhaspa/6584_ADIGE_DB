CREATE TABLE [Custom].[WBS_InEstrazione]
(
[Id_Lista] [int] NOT NULL IDENTITY(1, 1),
[WBS_Riferimento] [varchar] (24) COLLATE Latin1_General_CI_AS NOT NULL,
[Qta_Mancante] [numeric] (10, 2) NOT NULL,
[Qta_Iniziale] [numeric] (10, 2) NOT NULL,
[Qta_Estratta] [numeric] (10, 2) NULL,
[Id_Stato_Lista] [int] NOT NULL,
[DataOra_Esecuzione] [datetime] NOT NULL,
[DataOra_Chiusura] [datetime] NULL,
[DataOra_Ultima_Modifica] [datetime] NOT NULL,
[Id_Partizione_Destinazione] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[WBS_InEstrazione] ADD CONSTRAINT [PK_ORDINI_WBS] PRIMARY KEY CLUSTERED ([Id_Lista]) ON [PRIMARY]
GO
