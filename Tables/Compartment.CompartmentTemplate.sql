CREATE TABLE [Compartment].[CompartmentTemplate]
(
[Id_CompartmentTemplate] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (200) COLLATE Latin1_General_CI_AS NULL,
[Width] [int] NOT NULL,
[Depth] [int] NOT NULL,
[Id_Tipo_Udc] [varchar] (1) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[CompartmentTemplate] ADD CONSTRAINT [PK__Compartm__F8FB729362678EAC] PRIMARY KEY CLUSTERED ([Id_CompartmentTemplate]) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[CompartmentTemplate] ADD CONSTRAINT [FK__Compartme__Id_Ti__4B380934] FOREIGN KEY ([Id_Tipo_Udc]) REFERENCES [dbo].[Tipo_Udc] ([Id_Tipo_Udc])
GO
