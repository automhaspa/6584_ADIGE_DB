CREATE TABLE [dbo].[Udc_Testata]
(
[Id_Udc] [numeric] (18, 0) NOT NULL IDENTITY(1, 1),
[Data_Inserimento] [datetime] NOT NULL CONSTRAINT [DF_Saldi_Testata_Data_Inserimento] DEFAULT (getdate()),
[Codice_Udc] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Id_Ddt_Fittizio] [int] NULL,
[Specializzazione_Completa] [bit] NULL,
[Id_Tipo_Udc] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL,
[Stato_Allestimento] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[Altezza] [int] NOT NULL CONSTRAINT [DF_Udc_Testata_Altezza] DEFAULT ((0)),
[Larghezza] [int] NOT NULL CONSTRAINT [DF_Udc_Testata_Larghezza] DEFAULT ((0)),
[Profondita] [int] NOT NULL CONSTRAINT [DF_Udc_Testata_Profondita] DEFAULT ((0)),
[Peso] [int] NOT NULL CONSTRAINT [DF_Udc_Testata_Peso] DEFAULT ((0)),
[Blocco_Udc] [bit] NULL,
[Motivo_Blocco] [varchar] (100) COLLATE Latin1_General_CI_AS NULL,
[Contatore_Blocco] [int] NULL,
[Tara] [int] NULL,
[Associazione_Qta] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[Id_Gruppo_Lista] [int] NULL,
[Gruppo_Udc] [int] NULL,
[Udc_Attiva] [bit] NULL,
[Xml_Param] [xml] NULL,
[Percentuale_Riempimento] [int] NULL,
[INBOUND_PROGRESSIVE] [int] NULL,
[emptyUdc] AS ([dbo].[isEmptyUdc]([Id_Udc])),
[Da_Specializzare] [bit] NULL,
[Da_Compattare] [bit] NOT NULL CONSTRAINT [DF_Udc_Testata_Da_Compattare] DEFAULT ((0)),
[Udc_Kit] [int] NOT NULL CONSTRAINT [DF_Udc_Testata_Udc_Kit] DEFAULT ((0)),
[Control_Lot] [varchar] (40) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Udc_Testata] ADD CONSTRAINT [PK_Saldi_Testata] PRIMARY KEY CLUSTERED ([Id_Udc]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Udc_Testata] ON [dbo].[Udc_Testata] ([Codice_Udc]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Udc_Testata] ADD CONSTRAINT [FK_Udc_Testata_Tipo_Associazione_Qta] FOREIGN KEY ([Associazione_Qta]) REFERENCES [dbo].[Tipo_Associazione_Qta] ([Id_Associazione_Qta])
GO
ALTER TABLE [dbo].[Udc_Testata] ADD CONSTRAINT [FK_Udc_Testata_Tipo_Percentuali] FOREIGN KEY ([Percentuale_Riempimento]) REFERENCES [dbo].[Tipo_Percentuali] ([Id_Percentuale])
GO
ALTER TABLE [dbo].[Udc_Testata] ADD CONSTRAINT [FK_Udc_Testata_Tipo_Udc] FOREIGN KEY ([Id_Tipo_Udc]) REFERENCES [dbo].[Tipo_Udc] ([Id_Tipo_Udc])
GO
ALTER TABLE [dbo].[Udc_Testata] ADD CONSTRAINT [Fk_UdcTestata_IdDdt] FOREIGN KEY ([Id_Ddt_Fittizio]) REFERENCES [Custom].[AnagraficaDdtFittizi] ([ID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Se = 1 Qta_Grandi - Se = 0 Qta_Piccole - Se = NULL Niente (per la scelta della simulazione) ', 'SCHEMA', N'dbo', 'TABLE', N'Udc_Testata', 'COLUMN', N'Associazione_Qta'
GO
