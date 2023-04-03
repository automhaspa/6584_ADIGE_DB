CREATE TABLE [dbo].[Udc_Posizione]
(
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Id_Partizione] [int] NOT NULL,
[QuotaDeposito] [int] NULL,
[QuotaDepositoX] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Udc_Posizione] ADD CONSTRAINT [PK_Saldi_Posizione] PRIMARY KEY CLUSTERED ([Id_Udc]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Udc_Posizione] ADD CONSTRAINT [FK_Udc_Posizione_Partizioni] FOREIGN KEY ([Id_Partizione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Udc_Posizione] ADD CONSTRAINT [FK_Udc_Posizione_Udc_Testata] FOREIGN KEY ([Id_Udc]) REFERENCES [dbo].[Udc_Testata] ([Id_Udc])
GO
