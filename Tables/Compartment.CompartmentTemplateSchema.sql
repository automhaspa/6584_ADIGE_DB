CREATE TABLE [Compartment].[CompartmentTemplateSchema]
(
[Id_CompartmentTemplateSchema] [int] NOT NULL IDENTITY(1, 1),
[Id_CompartmentTemplate] [int] NOT NULL,
[X] [int] NOT NULL,
[Y] [int] NOT NULL,
[Id_Container] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[CompartmentTemplateSchema] ADD CONSTRAINT [PK__Compartm__0584DA3959FAC137] PRIMARY KEY CLUSTERED ([Id_CompartmentTemplateSchema]) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[CompartmentTemplateSchema] ADD CONSTRAINT [CompTemp_X_Y] UNIQUE NONCLUSTERED ([Id_CompartmentTemplate], [X], [Y]) ON [PRIMARY]
GO
ALTER TABLE [Compartment].[CompartmentTemplateSchema] ADD CONSTRAINT [FK__Compartme__Id_Co__418481C8] FOREIGN KEY ([Id_CompartmentTemplate]) REFERENCES [Compartment].[CompartmentTemplate] ([Id_CompartmentTemplate])
GO
ALTER TABLE [Compartment].[CompartmentTemplateSchema] ADD CONSTRAINT [FK__Compartme__Id_Co__5A502F92] FOREIGN KEY ([Id_Container]) REFERENCES [Compartment].[Container] ([Id_Container])
GO
