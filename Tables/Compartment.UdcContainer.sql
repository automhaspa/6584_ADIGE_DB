CREATE TABLE [Compartment].[UdcContainer]
(
[Id_UdcContainer] [int] NOT NULL IDENTITY(1, 1),
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Id_Container] [int] NOT NULL,
[X] [int] NOT NULL,
[Y] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[UdcContainer] ADD CONSTRAINT [PK__UdcConta__3D20D56FBB7C8A69] PRIMARY KEY CLUSTERED ([Id_UdcContainer]) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[UdcContainer] WITH NOCHECK ADD CONSTRAINT [FK__UdcContai__Id_Co__60FD2D21] FOREIGN KEY ([Id_Container]) REFERENCES [Compartment].[Container] ([Id_Container])
GO
ALTER TABLE [Compartment].[UdcContainer] WITH NOCHECK ADD CONSTRAINT [FK__UdcContai__Id_Ud__5F14E4AF] FOREIGN KEY ([Id_Udc]) REFERENCES [dbo].[Udc_Testata] ([Id_Udc])
GO
