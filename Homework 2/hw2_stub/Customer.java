import java.util.Arrays;
import java.util.List;
import java.util.Random;
import java.util.concurrent.CountDownLatch;
import java.util.ArrayList;

public class Customer implements Runnable {
    private Bakery bakery;
    private Random rnd;
    private List<BreadType> shoppingCart;
    private int shopTime;
    private int checkoutTime;
    private CountDownLatch doneSignal;
  
    /**
     * Initialize a customer object and randomize its shopping cart
     */
    
    public Customer(Bakery bakery, CountDownLatch l) {
        // TODO
        
        this.bakery = bakery;
        this.rnd = new Random();
        this.shoppingCart = new ArrayList<BreadType>();
        this.shopTime = 50 + rnd.nextInt(200); 
        this.checkoutTime = 50 + rnd.nextInt(200);
        // Fill the shopping cart with 1 to 3 random bread items
        fillShoppingCart();
        //customer has a ref to the same countdownlatch
        //this.doneSignal = doneSignal;
        doneSignal = l;       
    }

    /**
     * Run tasks for the customer
     */
    
    public void run() {
        // TODO
        try{
            Thread.sleep(this.shopTime);
            System.out.println(this + " started shopping.");
        }
        catch (InterruptedException e){
            e.printStackTrace();
        }

        //pick bread items from shelves
        for (BreadType bread : shoppingCart){
            //check for RYE
            if(bread == BreadType.RYE){
                try{
                    this.bakery.ryeShelf.acquire();
                }
                catch (InterruptedException e){
                    e.printStackTrace();
                }
                this.bakery.takeBread(BreadType.RYE);
                System.out.println(this + " added RYE bread to cart.");
                this.bakery.ryeShelf.release();
            }
            //check for SOURDOUGH
            else if(bread == BreadType.SOURDOUGH){
                try{
                    this.bakery.sourShelf.acquire();
                }
                catch (InterruptedException e){
                    e.printStackTrace();
                }
                this.bakery.takeBread(BreadType.SOURDOUGH);
                System.out.println(this + " added SOURDOUGH bread to cart.");
                this.bakery.sourShelf.release();
            }
            //check for WONDER
            else if(bread == BreadType.WONDER){
                try{
                    this.bakery.wonderShelf.acquire();
                }
                catch (InterruptedException e){
                    e.printStackTrace();
                }
                this.bakery.takeBread(BreadType.WONDER);
                System.out.println(this + " added WONDER bread to cart.");
                this.bakery.wonderShelf.release();
            }
        }

        try{
            //Thread.sleep(this.checkoutTime);
            this.bakery.cashier.acquire();
            System.out.println(this.toString() + " went to cashier");
            Thread.sleep(this.checkoutTime);
            this.bakery.update_sales.acquire();
            this.bakery.addSales(this.getItemsValue());
            System.out.println(this.toString() + " done checking out and finished shopping");
            this.bakery.cashier.release();
            this.bakery.update_sales.release();
            this.doneSignal.countDown();

        }
        catch (InterruptedException e){
            e.printStackTrace();
        }
        //go the the cashier if not blocked
        // try{
        //     bakery.cashier.acquire();
        // }
        // catch (InterruptedException e){
        //     e.printStackTrace();
        // }
    
        

    }

    /**
     * Return a string representation of the customer
     */
    public String toString() {
        return "Customer " + hashCode() + ": shoppingCart=" + Arrays.toString(shoppingCart.toArray()) + ", shopTime=" + shopTime + ", checkoutTime=" + checkoutTime;
    }

    /**
     * Add a bread item to the customer's shopping cart
     */
    private boolean addItem(BreadType bread) {
        // do not allow more than 3 items, chooseItems() does not call more than 3 times
        if (shoppingCart.size() >= 3) {
            return false;
        }
        shoppingCart.add(bread);
        return true;
    }

    /**
     * Fill the customer's shopping cart with 1 to 3 random breads
     */
    private void fillShoppingCart() {
        int itemCnt = 1 + rnd.nextInt(3);
        while (itemCnt > 0) {
            addItem(BreadType.values()[rnd.nextInt(BreadType.values().length)]);
            itemCnt--;
        }
    }

    /**
     * Calculate the total value of the items in the customer's shopping cart
     */
    private float getItemsValue() {
        float value = 0;
        for (BreadType bread : shoppingCart) {
            value += bread.getPrice();
        }
        return value;
    }
}
