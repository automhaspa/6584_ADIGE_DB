CREATE TABLE [Compartment].[Container]
(
[Id_Container] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (200) COLLATE Latin1_General_CI_AS NULL,
[Width] [int] NOT NULL,
[Depth] [int] NOT NULL,
[height] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[Container] ADD CONSTRAINT [PK__Containe__620FFCD058EF89A4] PRIMARY KEY CLUSTERED ([Id_Container]) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[Container] ADD CONSTRAINT [WDH__Unique_Constraint] UNIQUE NONCLUSTERED ([Width], [Depth], [height]) ON [PRIMARY]
GO
