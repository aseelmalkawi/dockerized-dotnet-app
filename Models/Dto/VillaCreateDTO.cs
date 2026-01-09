using System.ComponentModel.DataAnnotations;

namespace MagicVilla_VillaAPI.Models.Dto
{
    public class VillaCreateDTO
    {
        [Required]
        [MaxLength(15)]
        public string Name { get; set; }
        public string Location { get; set; }
        public float sqft { get; set; }
        public string Details { get; set; }
        [Range(0, 5)] 
        public double Rate { get; set; }
        [Required ]
        public string ImageUrl { get; set; }
        public DateTime CreatedDate { get; set; }
        public VillaCreateDTO()
        {
            CreatedDate = DateTime.Now;
        }
    }
}
