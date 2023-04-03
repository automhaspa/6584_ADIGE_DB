CREATE TABLE [Custom].[Tipo_Stato_Testata_OrdiniEntrata]
(
[Id_Stato_Riga] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Tipo_Stato_Testata_OrdiniEntrata] ADD CONSTRAINT [PK__Tipo_Sta__10F473B050946E07] PRIMARY KEY CLUSTERED ([Id_Stato_Riga]) ON [PRIMARY]
GO
