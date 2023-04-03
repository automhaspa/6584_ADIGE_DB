CREATE TABLE [Custom].[OrdineKittingUdc]
(
[Id_Testata_Lista] [int] NOT NULL,
[Id_Udc] [int] NOT NULL,
[Kit_Id] [int] NOT NULL,
[Stato_Udc_Kit] [int] NOT NULL CONSTRAINT [DF__OrdineKit__Stato__31233176] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[OrdineKittingUdc] ADD CONSTRAINT [PK__OrdineKi__7807759E581F44C1] PRIMARY KEY CLUSTERED ([Id_Testata_Lista], [Id_Udc], [Kit_Id]) ON [PRIMARY]
GO
