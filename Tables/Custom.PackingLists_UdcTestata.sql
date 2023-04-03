CREATE TABLE [Custom].[PackingLists_UdcTestata]
(
[Id_Udc_Packing_List] [numeric] (18, 0) NOT NULL,
[Id_Packing_List] [int] NOT NULL,
[Flag_Completa] [bit] NULL CONSTRAINT [DF__PackingLi__Flag___781FBE44] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[PackingLists_UdcTestata] ADD CONSTRAINT [PK__PackingL__239EF4286D0EACC4] PRIMARY KEY CLUSTERED ([Id_Udc_Packing_List]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[PackingLists_UdcTestata] ADD CONSTRAINT [FK__PackingLi__Id_Pa__62307D25] FOREIGN KEY ([Id_Packing_List]) REFERENCES [Custom].[PackingLists] ([Id_Packing_List]) ON UPDATE CASCADE
GO
ALTER TABLE [Custom].[PackingLists_UdcTestata] ADD CONSTRAINT [FK__PackingLi__Id_Ud__7A0806B6] FOREIGN KEY ([Id_Udc_Packing_List]) REFERENCES [dbo].[Udc_Testata] ([Id_Udc]) ON DELETE CASCADE
GO
