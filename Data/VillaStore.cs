 using MagicVilla_VillaAPI.Models.Dto;

namespace MagicVilla_VillaAPI.Data
{
    public static class VillaStore
    {
        public static new List<VillaDTO> villaList= new List<VillaDTO>
            {
                new VillaDTO {Id = 1 , Name = "Pool View" , Location = "Amman" , sqft = 3 } ,
                new VillaDTO {Id = 2 ,Name = "Beach View "  , Location = "salt" , sqft = 5} ,
                new VillaDTO { Id = 3, Name = "River View"   , Location = "salt" , sqft = 2.5f}
            };
    }  
}


/* static class is a class that is designed to contain
 only static members, such as static fields, static properties,
and static methods. A static class cannot be instantiated */



/* this descripe the VillaStore
         * This code creates a new List object containing three Villa objects,  
         and then returns that list as an IEnumerable<Villa> object.

        Each Villa object is created using the new keyword followed by the name of the class, Villa.
        Within the braces { }, the Id and Name properties of each Villa object are initialized with specific values.


        The List<Villa> constructor takes this collection of Villa objects and creates a new List object that
        contains those objects. This list is then returned as an IEnumerable<Villa> object by the GetVillas() method.

        */