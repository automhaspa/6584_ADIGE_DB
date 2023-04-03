CREATE TABLE [Custom].[AnagraficaBancali]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Codice_Barcode] [varchar] (10) COLLATE Latin1_General_CI_AS NULL,
[DataOra_Creazione] [datetime] NULL CONSTRAINT [DF__Anagrafic__DataO__09E968C4] DEFAULT (getdate()),
[Stato] [int] NOT NULL CONSTRAINT [DF_AnagraficaBancali_Stato] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[AnagraficaBancali] ADD CONSTRAINT [PK__Anagrafi__3214EC2752C6252E] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[AnagraficaBancali] ADD CONSTRAINT [UQ__Anagrafi__281D03F5CF2539A5] UNIQUE NONCLUSTERED ([Codice_Barcode]) ON [PRIMARY]
GO
